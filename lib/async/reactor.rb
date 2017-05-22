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
	class TimeoutError < RuntimeError
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
				
				reactor.async(*args, &block)
			else
				reactor = self.new
				
				begin
					reactor.run(*args, &block)
				ensure
					reactor.close
				end
				
				return reactor
			end
		end
	
		# @param wrappers [Hash] A mapping for wrapping pre-existing IO objects.
		def initialize(wrappers: IO)
			super(nil)
			
			@wrappers = wrappers
			
			@selector = NIO::Selector.new
			@timers = Timers::Group.new
			
			@stopped = true
		end
	
		# @attr wrappers [Object] 
		attr :wrappers
		# @attr stopped [Boolean] 
		attr :stopped
		
		def_delegators :@timers, :every, :after
		
		# Wrap a given IO object and associate it with a specific task.
		# @param io [IO] The instance to wrap.
		# @return [Wrapper]
		def wrap(io)
			@wrappers[io].new(io, self)
		end
	
		# Run the given block asynchronously, passing the arguments to `Task#with`.
		def with(*args, &block)
			async do |task|
				task.with(*args, &block)
			end
		end
	
		# Start an asynchronous task within the specified reactor. The task will be
		# executed until the first blocking call, at which point it will yield and
		# and this method will return.
		#
		# This is the main entry point for scheduling asynchronus tasks.
		#
		# @yield [Task] Executed within the asynchronous task.
		# @return [Task] The task that was 
		def async(&block)
			task = Task.new(self, &block)
			
			# I want to take a moment to explain the logic of this.
			# When calling an async block, we deterministically execute it until the
			# first blocking operation. We don't *have* to do this - we could schedule
			# it for later execution, but it's useful to:
			# - Fail at the point of call where possible.
			# - Execute determinstically where possible.
			# - Avoid overhead if no blocking operation is performed.
			task.run
			
			# Async.logger.debug "Initial execution of task #{fiber} complete (#{result} -> #{fiber.alive?})..."
			return task
		end
		
		def register(*args)
			@selector.register(*args)
		end
	
		# Stop the reactor at the earliest convenience.
		# @return [void]
		def stop
			unless @stopped
				@stopped = true
				@selector.wakeup
			end
		end
	
		# Run the reactor until either all tasks complete or {#stop} is invoked.
		# Proxies arguments to {#async} immediately before entering the loop.
		def run(*args, &block)
			raise RuntimeError, 'Reactor has been closed' if @selector.nil?
			
			@stopped = false
			
			# Allow the user to kick of the initial async tasks.
			async(*args, &block) if block_given?
			
			@timers.wait do |interval|
				# - nil: no timers
				# - -ve: timers expired already
				# -   0: timers ready to fire
				# - +ve: timers waiting to fire
				interval = 0 if interval && interval < 0
				
				Async.logger.debug{"[#{self} Pre] Updating #{@children.count} children..."}
				Async.logger.debug{@children.collect{|child| [child.to_s, child.alive?]}.inspect}
				# As timeouts may have been updated, and caused fibers to complete, we should check this.
				
				# If there is nothing to do, then finish:
				Async.logger.debug{"[#{self}] @children.empty? = #{@children.empty?} && interval #{interval.inspect}"}
				return if @children.empty? && interval.nil?
				
				Async.logger.debug{"Selecting with #{@children.count} fibers interval = #{interval}..."}
				if monitors = @selector.select(interval)
					monitors.each do |monitor|
						if fiber = monitor.value
							# Async.logger.debug "Resuming task #{task} due to IO..."
							fiber.resume # if fiber.alive?
						end
					end
				end
			end until @stopped
			
			return self
		ensure
			Async.logger.debug{"[#{self} Ensure] Exiting run-loop (stopped: #{@stopped} exception: #{$!})..."}
			Async.logger.debug{@children.collect{|child| [child.to_s, child.alive?]}.inspect}
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
			task = Fiber.current
			
			timer = self.after(duration) do
				if task.alive?
					task.resume
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
			task = Fiber.current
			
			timer = self.after(duration) do
				if task.alive?
					error = TimeoutError.new("execution expired")
					error.set_backtrace backtrace
					task.resume error
				end
			end
			
			yield
		ensure
			timer.cancel if timer
		end
	end
end
