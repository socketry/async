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
		def self.run(*args, **options, &block)
			if current = Task.current?
				reactor = current.reactor
				
				return reactor.async(*args, **options, &block)
			else
				reactor = self.new(**options)
				
				begin
					return reactor.run(*args, &block)
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

		# Set up a hook pair to be called back when instantiating a task.
		# @param before_create [Lambda] will be evaluated before a task's fiber is created. Takes 0 params.
		# @param after_create [Lambda] will be called in the new fiber and passed the return value of before_create. Takes 1 param.
		def self.hook(before_create: nil, after_create: nil)
			Task.current.reactor.hook(before_create: before_create, after_create: after_create)
		end
		
		def initialize(parent = nil, selector: self.class.selector, logger: nil)
			super(parent)
			
			@selector = selector
			@timers = Timers::Group.new
			@logger = logger
			
			@ready = []
			@running = []
			
			@stopped = true
		end
		
		def logger
			@logger ||= Console.logger
		end
		
		def to_s
			"\#<#{self.description} (#{@stopped ? 'stopped' : 'running'})>"
		end
		
		# @attr stopped [Boolean]
		attr :stopped
		
		def stopped?
			@stopped
		end
		
		# TODO Remove these in next major release. They are too confusing to use correctly.
		def_delegators :@timers, :every, :after
		
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
			
			# logger.debug "Initial execution of task #{fiber} complete (#{result} -> #{fiber.alive?})..."
			return task
		end
		
		def register(io, interest, value = Fiber.current)
			monitor = @selector.register(io, interest)
			monitor.value = value
			
			return monitor
		end
		
		# Stop the reactor at the earliest convenience. Can be called from a different thread safely.
		# @return [void]
		def stop
			unless @stopped
				@stopped = true
				@selector.wakeup
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
			
			Fiber.yield
		end
		
		def finished?
			# I'm not sure if checking `@running.empty?` is really required.
			super && @ready.empty? && @running.empty?
		end
		
		# Run the reactor until either all tasks complete or {#stop} is invoked.
		# Proxies arguments to {#async} immediately before entering the loop.
		def run(*args, &block)
			raise RuntimeError, 'Reactor has been closed' if @selector.nil?
			
			@stopped = false
			
			initial_task = self.async(*args, &block) if block_given?
			
			until @stopped
				logger.debug(self) {"@ready = #{@ready} @running = #{@running}"}
				
				if @ready.any?
					# running used to correctly answer on `finished?`, and to reuse Array object.
					@running, @ready = @ready, @running
					
					@running.each do |fiber|
						fiber.resume if fiber.alive?
					end
					
					@running.clear
				end
				
				if @ready.empty?
					interval = @timers.wait_interval
				else
					# if there are tasks ready to execute, don't sleep:
					interval = 0
				end
				
				# If there is no interval to wait (thus no timers), and no tasks, we could be done:
				if interval.nil?
					if self.finished?
						# If there is nothing to do, then finish:
						return initial_task
					end
				elsif interval < 0
					# We have timers ready to fire, don't sleep in the selctor:
					interval = 0
				end
				
				logger.debug(self) {"Selecting with #{@children&.size} children with interval = #{interval ? interval.round(2) : 'infinite'}..."}
				if monitors = @selector.select(interval)
					monitors.each do |monitor|
						monitor.value.resume
					end
				end
				
				@timers.fire
			end
			
			return initial_task
		ensure
			logger.debug(self) {"Exiting run-loop because #{$! ? $! : 'finished'}."}
			
			@stopped = true
		end
	
		# Stop each of the children tasks and close the selector.
		# 
		# @return [void]
		def close
			@children&.each(&:stop)
			
			# TODO Should we also clear all timers?
			@selector.close
			@selector = nil
		end
		
		# Check if the selector has been closed.
		# @return [Boolean]
		def closed?
			@selector.nil?
		end
	
		# Put the calling fiber to sleep for a given ammount of time.
		# @param duration [Numeric] The time in seconds, to sleep for.
		def sleep(duration)
			fiber = Fiber.current
			
			timer = self.after(duration) do
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
			
			timer = self.after(timeout) do
				if fiber.alive?
					error = exception.new("execution expired")
					fiber.resume error
				end
			end
			
			yield timer
		ensure
			timer.cancel if timer
		end
		
		# TODO remove
		def timeout(*args, &block)
			warn "#{self.class}\#timeout(...) is deprecated, use #{self.class}\#with_timeout(...) instead."
			
			with_timeout(*args, &block)
		end

		# @return [Array] A list of callbacks to be called before and after creating a fiber.
		# Each is a Hash with keys :before_create (a lambda to be called in the original
		# fiber) and :after_create (a lambda to receive the value as a parameter).
		def hooks
			@hooks ||= []
		end

		# Before creating an async task's fiber, call all the before_create hooks and return their values.
		def call_before_hooks
			hooks.map { |hook| hook[:before_create]&.call }
		end

		# In a new async task's fiber, pass the return values of the before_create hooks to the
		# after_create hooks.
		def call_after_hooks(payloads)
			hooks.each_with_index do |hook, index|
				hook[:after_create]&.call(payloads[index])
			end
		end

		# Add a hook pair.
		def hook(before_create:, after_create:)
			hooks << {
				before_create: before_create,
				after_create: after_create,
			}
		end
	end
end
