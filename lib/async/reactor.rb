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
	# Raised if a timeout occurs on a specific Fiber. Handled gracefully by {Task}.
	class TimeoutError < Exception
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
		def self.run(*args, &block)
			if current = Task.current?
				reactor = current.reactor
				
				return reactor.async(*args, &block)
			else
				reactor = self.new
				
				begin
					return reactor.run(*args, &block)
				ensure
					reactor.close
				end
			end
		end
		
		def initialize(parent = nil, selector: NIO::Selector.new)
			super(parent)
			
			@selector = selector
			@timers = Timers::Group.new
			
			@ready = []
			@running = []
			
			@stopped = true
		end
		
		def to_s
			"<#{self.description} stopped=#{@stopped}>"
		end
		
		# @attr stopped [Boolean]
		attr :stopped
		
		def stopped?
			@stopped
		end
		
		def_delegators :@timers, :every, :after
		
		# Start an asynchronous task within the specified reactor. The task will be
		# executed until the first blocking call, at which point it will yield and
		# and this method will return.
		#
		# This is the main entry point for scheduling asynchronus tasks.
		#
		# @yield [Task] Executed within the asynchronous task.
		# @return [Task] The task that was 
		def async(*args, &block)
			task = Task.new(self, &block)
			
			# I want to take a moment to explain the logic of this.
			# When calling an async block, we deterministically execute it until the
			# first blocking operation. We don't *have* to do this - we could schedule
			# it for later execution, but it's useful to:
			# - Fail at the point of call where possible.
			# - Execute determinstically where possible.
			# - Avoid overhead if no blocking operation is performed.
			task.run(*args)
			
			# Async.logger.debug "Initial execution of task #{fiber} complete (#{result} -> #{fiber.alive?})..."
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
			
			# Allow the user to kick of the initial async tasks.
			initial_task = async(*args, &block) if block_given?
			
			@timers.wait do |interval|
				# running used to correctly answer on `finished?`, and to reuse Array object.
				@running, @ready = @ready, @running
				if @running.any?
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
				
				# Async.logger.debug(self) {"Updating #{@children.count} children..."}
				# As timeouts may have been updated, and caused fibers to complete, we should check this.
				
				# If there is nothing to do, then finish:
				if !interval && self.finished?
					return initial_task
				end
				
				# Async.logger.debug(self) {"Selecting with #{@children.count} fibers interval = #{interval.inspect}..."}
				if monitors = @selector.select(interval)
					monitors.each do |monitor|
						monitor.value.resume
					end
				end
			end until @stopped
			
			return initial_task
		ensure
			Async.logger.debug(self) {"Exiting run-loop because #{$! ? $!.inspect : 'finished'}."}
			@stopped = true
		end
	
		# Stop each of the children tasks and close the selector.
		# 
		# @return [void]
		def close
			@children.each(&:stop)
			
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
		
		# Invoke the block, but after the timeout, raise {TimeoutError} in any
		# currenly blocking operation.
		# @param duration [Integer] The time in seconds, in which the task should 
		#   complete.
		def timeout(duration)
			backtrace = caller
			fiber = Fiber.current
			
			timer = self.after(duration) do
				if fiber.alive?
					error = TimeoutError.new("execution expired")
					error.set_backtrace backtrace
					fiber.resume error
				end
			end
			
			yield
		ensure
			timer.cancel if timer
		end
	end
end
