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

require 'fiber'

require_relative 'node'
require_relative 'condition'

module Async
	# Raised when a task is explicitly stopped.
	class Stop < Exception
		class Later
			def initialize(task)
				@task = task
			end
			
			def alive?
				true
			end
			
			def transfer
				@task.stop
			end
		end
	end
	
	# Raised if a timeout occurs on a specific Fiber. Handled gracefully by `Task`.
	class TimeoutError < StandardError
		def initialize(message = "execution expired")
			super
		end
	end
	
	# A task represents the state associated with the execution of an asynchronous
	# block.
	class Task < Node
		def self.yield
			Fiber.scheduler.transfer
		end
		
		# The preferred method to invoke asynchronous behavior at the top level.
		#
		# - When invoked within an existing reactor task, it will run the given block
		# asynchronously. Will return the task once it has been scheduled.
		# - When invoked at the top level, will create and run a reactor, and invoke
		# the block as an asynchronous task. Will block until the reactor finishes
		# running.
		def self.run(*arguments, **options, &block)
			if current = self.current?
				return current.async(*arguments, **options, &block)
			else
				scheduler = Scheduler.new
				scheduler.set!
				
				begin
					Fiber.schedule(&block)
					return self.run(*arguments, **options, &block)
				ensure
					scheduler.clear!
				end
			end
		end
		
		# Create a new task.
		# @param reactor [Async::Reactor] the reactor this task will run within.
		# @param parent [Async::Task] the parent task.
		def initialize(parent = Task.current?, finished: nil, **options, &block)
			super(parent, **options)
			
			@status = :initialized
			@result = nil
			@finished = finished
			
			@block = block
			@fiber = nil
		end
		
		def reactor
			self.root
		end
		
		if Fiber.current.respond_to?(:backtrace)
			def backtrace(*arguments)
				@fiber&.backtrace(*arguments)
			end
		end
		
		def to_s
			"\#<#{self.description} (#{@status})>"
		end
		
		def sleep(duration = nil)
			super
		end
		
		def with_timeout(timeout, exception = TimeoutError, message = "execution expired", &block)
			Fiber.scheduler.timeout_after(timeout, exception, message, &block)
		end
		
		# Yield back to the reactor and allow other fibers to execute.
		def yield
			Fiber.scheduler.yield
		end
		
		# @attr fiber [Fiber] The fiber which is being used for the execution of this task.
		attr :fiber
		
		def alive?
			@fiber&.alive?
		end
		
		# @attr status [Symbol] The status of the execution of the fiber, one of `:initialized`, `:running`, `:complete`, `:stopped` or `:failed`.
		attr :status
		
		# Begin the execution of the task.
		def run(*arguments)
			if @status == :initialized
				@status = :running
				
				schedule(arguments)
			else
				raise RuntimeError, "Task already running!"
			end
		end
		
		def async(*arguments, **options, &block)
			task = Task.new(self, **options, &block)
			
			task.run(*arguments)
			
			return task
		end
		
		# Retrieve the current result of the task. Will cause the caller to wait until result is available.
		# @raise [RuntimeError] if the task's fiber is the current fiber.
		# @return [Object] the final expression/result of the task's block.
		def wait
			raise "Cannot wait on own fiber" if Fiber.current.equal?(@fiber)
			
			if running?
				raise "Cannot wait outside of reactor" unless Fiber.scheduler
				
				@finished ||= Condition.new
				@finished.wait
			end
			
			case @result
			when Exception
				raise @result
			else
				return @result
			end
		end
		
		# Access the result of the task without waiting. May be nil if the task is not completed.
		attr :result
		
		# Stop the task and all of its children.
		def stop(later = false)
			if self.stopped?
				# If we already stopped this task... don't try to stop it again:
				return
			end
			
			if self.running?
				if self.current?
					if later
						Fiber.scheduler << Stop::Later.new(self)
					else
						raise Stop, "Stopping current task!"
					end
				elsif @fiber&.alive?
					begin
						Fiber.scheduler.raise(@fiber, Stop)
					rescue FiberError
						Fiber.scheduler << Stop::Later.new(self)
					end
				end
			else
				# We are not running, but children might be, so transition directly into stopped state:
				stop!
			end
		end
		
		# Lookup the {Task} for the current fiber. Raise `RuntimeError` if none is available.
		# @return [Async::Task]
		# @raise [RuntimeError] if task was not {set!} for the current fiber.
		def self.current
			Thread.current[:async_task] or raise RuntimeError, "No async task available!"
		end
		
		# Check if there is a task defined for the current fiber.
		# @return [Async::Task, nil]
		def self.current?
			Thread.current[:async_task]
		end
		
		def current?
			self.equal?(Thread.current[:async_task])
		end
		
		# Check if the task is running.
		# @return [Boolean]
		def running?
			@status == :running
		end
		
		# Whether we can remove this node from the reactor graph.
		# @return [Boolean]
		def finished?
			super && @status != :running
		end
		
		def failed?
			@status == :failed
		end
		
		def stopping?
			@status == :stopping
		end
		
		def stopped?
			@status == :stopped
		end
		
		def complete?
			@status == :complete
		end
		
		private
		
		# This is a very tricky aspect of tasks to get right. I've modelled it after `Thread` but it's slightly different in that the exception can propagate back up through the reactor. If the user writes code which raises an exception, that exception should always be visible, i.e. cause a failure. If it's not visible, such code fails silently and can be very difficult to debug.
		# As an explcit choice, the user can start a task which doesn't propagate exceptions. This only applies to `StandardError` and derived tasks. This allows tasks to internally capture their error state which is raised when invoking `Task#result` similar to how `Thread#join` works. This mode makes {ruby Async::Task} behave more like a promise, and you would need to ensure that someone calls `Task#result` otherwise you might miss important errors.
		def fail!(exception = nil, propagate = true)
			@status = :failed
			@result = exception
			
			if propagate
				raise
			elsif @finished.nil?
				# If no one has called wait, we log this as an error:
				Console.logger.error(self) {$!}
			else
				Console.logger.debug(self) {$!}
			end
		end
		
		def stop!
			# Console.logger.info(self, self.annotation) {"Task was stopped with #{@children&.size.inspect} children!"}
			@status = :stopped
			
			stop_children(true)
		end
		
		def schedule(arguments)
			@fiber = Fiber.new do
				set!
				
				begin
					@result = @block.call(self, *arguments)
					@status = :complete
					# Console.logger.debug(self) {"Task was completed with #{@children.size} children!"}
				rescue Stop
					stop!
				rescue StandardError => error
					fail!(error, false)
				rescue Exception => exception
					fail!(exception, true)
				ensure
					# Console.logger.info(self) {"Task ensure $! = #{$!} with #{@children&.size.inspect} children!"}
					finish!
				end
			end
			
			self.root.resume(@fiber)
		end
		
		# Finish the current task, and all bound bound IO objects.
		def finish!
			# Allow the fiber to be recycled.
			@fiber = nil
			
			# Attempt to remove this node from the task tree.
			consume
			
			# If this task was being used as a future, signal completion here:
			if @finished
				@finished.signal(@result)
			end
		end
		
		# Set the current fiber's `:async_task` to this task.
		def set!
			# This is actually fiber-local:
			Thread.current[:async_task] = self
		end
	end
end
