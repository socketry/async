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
			"<#{self.description} stopped=#{@stopped}>"
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
		def async(*args, **options, &block)
			task = Task.new(self, **options, &block)
			
			# I want to take a moment to explain the logic of this.
			# When calling an async block, we deterministically execute it until the
			# first blocking operation. We don't *have* to do this - we could schedule
			# it for later execution, but it's useful to:
			# - Fail at the point of call where possible.
			# - Execute determinstically where possible.
			# - Avoid overhead if no blocking operation is performed.
			task.run(*args)
			
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
			super && @ready.empty? && @running.empty?
		end
		
		# Run the reactor until either all tasks complete or {#stop} is invoked.
		# Proxies arguments to {#async} immediately before entering the loop.
		def run(*args, &block)
			raise RuntimeError, 'Reactor has been closed' if @selector.nil?
			
			@stopped = false
			
			initial_task = self.async(*args, &block) if block_given?
			
			@timers.wait do |interval|
				# logger.debug(self) {"@ready = #{@ready} @running = #{@running}"}
				
				if @ready.any?
					# running used to correctly answer on `finished?`, and to reuse Array object.
					@running, @ready = @ready, @running
					
					@running.each do |fiber|
						fiber.resume if fiber.alive?
					end
					
					@running.clear
					
					# if there are tasks ready to execute, don't sleep.
					if @ready.any?
						interval = 0
					else
						# The above tasks may schedule, cancel or affect timers in some way. We need to compute a new wait interval for the blocking selector call below:
						interval = @timers.wait_interval
					end
				end
				
				# - nil: no timers
				# - -ve: timers expired already
				# -   0: timers ready to fire
				# - +ve: timers waiting to fire
				if interval && interval < 0
					interval = 0
				end
				
				# logger.debug(self) {"Updating #{@children.count} children..."}
				# As timeouts may have been updated, and caused fibers to complete, we should check this.
				
				# If there is nothing to do, then finish:
				if !interval && self.finished?
					return initial_task
				end
				
				# logger.debug(self) {"Selecting with #{@children.count} fibers interval = #{interval.inspect}..."}
				if monitors = @selector.select(interval)
					monitors.each do |monitor|
						monitor.value.resume
					end
				end
			end until @stopped
			
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
	end
end
