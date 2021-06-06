# frozen_string_literal: true

# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'logger'
require_relative 'task'
require_relative 'wrapper'
require_relative 'scheduler'

require 'nio'
require 'timers'
require 'forwardable'

module Async
	# Raised if a timeout occurs on a specific Fiber. Handled gracefully by `Task`.
	class TimeoutError < StandardError
	end
	
	# An asynchronous, cooperatively scheduled event reactor.
	class Reactor < Node
		extend Forwardable
		
		# The preferred method to invoke asynchronous behavior at the top level.
		#
		# - When invoked within an existing reactor task, it will run the given block
		# asynchronously. Will return the task once it has been scheduled.
		# - When invoked at the top level, will create and run a reactor, and invoke
		# the block as an asynchronous task. Will block until the reactor finishes
		# running.
		def self.run(*arguments, **options, &block)
			if current = Task.current?
				return current.async(*arguments, **options, &block)
			else
				reactor = self.new
				
				begin
					return reactor.run(*arguments, **options, &block)
				ensure
					reactor.close
				end
			end
		end
		
		def self.selector
			if backend = ENV['ASYNC_BACKEND']&.to_sym
				if NIO::Selector.backends.include?(backend)
					return NIO::Selector.new(backend)
				else
					warn "Could not find ASYNC_BACKEND=#{backend}!"
				end
			end
			
			return NIO::Selector.new
		end
		
		def initialize(parent = nil, selector: self.class.selector, logger: nil)
			super(parent)
			
			@selector = selector
			@timers = Timers::Group.new
			@logger = logger
			
			@ready = []
			@running = []
			
			if Scheduler.supported?
				@scheduler = Scheduler.new(self)
			else
				@scheduler = nil
			end
			
			@interrupted = false
			@guard = Mutex.new
			@blocked = 0
			@unblocked = []
		end
		
		attr :scheduler
		attr :logger
		
		# @reentrant Not thread safe.
		def block(blocker, timeout)
			fiber = Fiber.current
			
			if timeout
				timer = @timers.after(timeout) do
					if fiber.alive?
						fiber.resume(false)
					end
				end
			end
			
			begin
				@blocked += 1
				Task.yield
			ensure
				@blocked -= 1
			end
		ensure
			timer&.cancel
		end
		
		# @reentrant Thread safe.
		def unblock(blocker, fiber)
			@guard.synchronize do
				@unblocked << fiber
				@selector.wakeup
			end
		end
		
		def fiber(&block)
			if @scheduler
				Fiber.new(blocking: false, &block)
			else
				Fiber.new(&block)
			end
		end
		
		def to_s
			"\#<#{self.description} #{@children&.size || 0} children (#{stopped? ? 'stopped' : 'running'})>"
		end
		
		def stopped?
			@children.nil?
		end
		
		# Start an asynchronous task within the specified reactor. The task will be
		# executed until the first blocking call, at which point it will yield and
		# and this method will return.
		#
		# This is the main entry point for scheduling asynchronus tasks.
		#
		# @yield [Task] Executed within the task.
		# @return [Task] The task that was scheduled into the reactor.
		def async(*arguments, **options, &block)
			task = Task.new(self, **options, &block)
			
			# I want to take a moment to explain the logic of this.
			# When calling an async block, we deterministically execute it until the
			# first blocking operation. We don't *have* to do this - we could schedule
			# it for later execution, but it's useful to:
			# - Fail at the point of the method call where possible.
			# - Execute determinstically where possible.
			# - Avoid scheduler overhead if no blocking operation is performed.
			task.run(*arguments)
			
			# Console.logger.debug "Initial execution of task #{fiber} complete (#{result} -> #{fiber.alive?})..."
			return task
		end
		
		def register(io, interest, value = Fiber.current)
			monitor = @selector.register(io, interest)
			monitor.value = value
			
			return monitor
		end
		
		# Interrupt the reactor at the earliest convenience. Can be called from a different thread safely.
		def interrupt
			@guard.synchronize do
				unless @interrupted
					@interrupted = true
					@selector.wakeup
				end
			end
		end
		
		# Schedule a fiber (or equivalent object) to be resumed on the next loop through the reactor.
		# @param fiber [#resume] The object to be resumed on the next iteration of the run-loop.
		def << fiber
			@ready << fiber
		end
		
		# Yield the current fiber and resume it on the next iteration of the event loop.
		def yield(fiber = Fiber.current)
			@ready << fiber
			
			Task.yield
		end
		
		def finished?
			# TODO I'm not sure if checking `@running.empty?` is really required.
			super && @ready.empty? && @running.empty? && @blocked.zero?
		end
		
		# Run one iteration of the event loop.
		# @param timeout [Float | nil] the maximum timeout, or if nil, indefinite.
		# @return [Boolean] whether there is more work to do.
		def run_once(timeout = nil)
			# Console.logger.debug(self) {"@ready = #{@ready} @running = #{@running}"}
			
			if @ready.any?
				# running used to correctly answer on `finished?`, and to reuse Array object.
				@running, @ready = @ready, @running
				
				@running.each do |fiber|
					fiber.resume if fiber.alive?
				end
				
				@running.clear
			end
			
			if @unblocked.any?
				unblocked = Array.new
				
				@guard.synchronize do
					unblocked, @unblocked = @unblocked, unblocked
				end
				
				while fiber = unblocked.pop
					fiber.resume if fiber.alive?
				end
			end
			
			if @ready.empty?
				interval = @timers.wait_interval
			else
				# if there are tasks ready to execute, don't sleep:
				interval = 0
			end
			
			# If we are finished, we stop the task tree and exit:
			if self.finished?
				return false
			end
			
			# If there is no interval to wait (thus no timers), and no tasks, we could be done:
			if interval.nil?
				# Allow the user to specify a maximum interval if we would otherwise be sleeping indefinitely:
				interval = timeout
			elsif interval < 0
				# We have timers ready to fire, don't sleep in the selctor:
				interval = 0
			elsif timeout and interval > timeout
				interval = timeout
			end
			
			# Console.logger.info(self) {"Selecting with #{@children&.size} children with interval = #{interval ? interval.round(2) : 'infinite'}..."}
			if monitors = @selector.select(interval)
				monitors.each do |monitor|
					monitor.value.resume
				end
			end
			
			@timers.fire
			
			# We check and clear the interrupted flag here:
			if @interrupted
				@guard.synchronize do
					@interrupted = false
				end
				
				return false
			end
			
			# The reactor still has work to do:
			return true
		end
		
		# Run the reactor until all tasks are finished. Proxies arguments to {#async} immediately before entering the loop, if a block is provided.
		def run(*arguments, **options, &block)
			raise RuntimeError, 'Reactor has been closed' if @selector.nil?
			
			@scheduler&.set!
			
			initial_task = self.async(*arguments, **options, &block) if block_given?
			
			while self.run_once
				# Round and round we go!
			end
			
			return initial_task
		ensure
			@scheduler&.clear!
			Console.logger.debug(self) {"Exiting run-loop because #{$! ? $! : 'finished'}."}
		end
		
		# Stop each of the children tasks and close the selector.
		def close
			# This is a critical step. Because tasks could be stored as instance variables, and since the reactor is (probably) going out of scope, we need to ensure they are stopped. Otherwise, the tasks will belong to a reactor that will never run again and are not stopped:
			self.terminate
			
			@selector.close
			@selector = nil
		end
		
		# Check if the selector has been closed.
		# @returns [Boolean]
		def closed?
			@selector.nil?
		end
		
		# Put the calling fiber to sleep for a given ammount of time.
		# @parameter duration [Numeric] The time in seconds, to sleep for.
		def sleep(duration)
			fiber = Fiber.current
			
			timer = @timers.after(duration) do
				if fiber.alive?
					fiber.resume
				end
			end
			
			Task.yield
		ensure
			timer.cancel if timer
		end
		
		# Invoke the block, but after the specified timeout, raise {TimeoutError} in any currenly blocking operation. If the block runs to completion before the timeout occurs or there are no non-blocking operations after the timeout expires, the code will complete without any exception.
		# @param duration [Numeric] The time in seconds, in which the task should 
		#   complete.
		def with_timeout(timeout, exception = TimeoutError)
			fiber = Fiber.current
			
			timer = @timers.after(timeout) do
				if fiber.alive?
					error = exception.new("execution expired")
					fiber.resume(error)
				end
			end
			
			yield timer
		ensure
			timer.cancel if timer
		end
	end
end
