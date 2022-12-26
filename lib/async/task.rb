# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2017, by Devin Christensen.
# Copyright, 2020, by Patrik Wenger.

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
	# @public Since `stable-v1`.
	class TimeoutError < StandardError
		def initialize(message = "execution expired")
			super
		end
	end
	
	# Encapsulates the state of a running task and it's result.
	# @public Since `stable-v1`.
	class Task < Node
		# @deprecated With no replacement.
		def self.yield
			Fiber.scheduler.transfer
		end
		
		# Create a new task.
		# @parameter reactor [Reactor] the reactor this task will run within.
		# @parameter parent [Task] the parent task.
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
		
		# @deprecated Prefer {Kernel#sleep} except when compatibility with `stable-v1` is required.
		def sleep(duration = nil)
			super
		end
		
		# Execute the given block of code, raising the specified exception if it exceeds the given duration during a non-blocking operation.
		def with_timeout(duration, exception = TimeoutError, message = "execution expired", &block)
			Fiber.scheduler.with_timeout(duration, exception, message, &block)
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
				
				schedule do
					@block.call(self, *arguments)
				end
			else
				raise RuntimeError, "Task already running!"
			end
		end
		
		# Run an asynchronous task as a child of the current task.
		def async(*arguments, **options, &block)
			raise "Cannot create child task within a task that has finished execution!" if self.finished?
			
			task = Task.new(self, **options, &block)
			
			task.run(*arguments)
			
			return task
		end
		
		# Retrieve the current result of the task. Will cause the caller to wait until result is available. If the result was an exception, raise that exception.
		#
		# Conceptually speaking, waiting on a task should return a result, and if it throws an exception, this is certainly an exceptional case that should represent a failure in your program, not an expected outcome. In other words, you should not design your programs to expect exceptions from `#wait` as a normal flow control, and prefer to catch known exceptions within the task itself and return a result that captures the intention of the failure, e.g. a `TimeoutError` might simply return `nil` or `false` to indicate that the operation did not generate a valid result (as a timeout was an expected outcome of the internal operation in this case).
		#
		# @raises [RuntimeError] If the task's fiber is the current fiber.
		# @returns [Object] The final expression/result of the task's block.
		def wait
			raise "Cannot wait on own fiber!" if Fiber.current.equal?(@fiber)
			
			if running?
				@finished ||= Condition.new
				@finished.wait
			end
			
			if @result.is_a?(Exception)
				raise @result
			else
				return @result
			end
		end
		
		# Access the result of the task without waiting. May be nil if the task is not completed. Does not raise exceptions.
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
						Fiber.scheduler.push(Stop::Later.new(self))
					else
						raise Stop, "Stopping current task!"
					end
				elsif @fiber&.alive?
					begin
						Fiber.scheduler.raise(@fiber, Stop)
					rescue FiberError
						Fiber.scheduler.push(Stop::Later.new(self))
					end
				end
			else
				# We are not running, but children might be, so transition directly into stopped state:
				stop!
			end
		end
		
		# Lookup the {Task} for the current fiber. Raise `RuntimeError` if none is available.
		# @returns [Task]
		# @raises[RuntimeError] If task was not {set!} for the current fiber.
		def self.current
			Thread.current[:async_task] or raise RuntimeError, "No async task available!"
		end
		
		# Check if there is a task defined for the current fiber.
		# @returns [Task | Nil]
		def self.current?
			Thread.current[:async_task]
		end
		
		def current?
			self.equal?(Thread.current[:async_task])
		end
		
		# Check if the task is running.
		# @returns [Boolean]
		def running?
			@status == :running
		end
		
		# Whether we can remove this node from the reactor graph.
		# @returns [Boolean]
		def finished?
			super && @fiber.nil?
		end
		
		def failed?
			@status == :failed
		end
		
		def stopped?
			@status == :stopped
		end
		
		def complete?
			@status == :complete
		end
		
		private
		
		# This is a very tricky aspect of tasks to get right. I've modelled it after `Thread` but it's slightly different in that the exception can propagate back up through the reactor. If the user writes code which raises an exception, that exception should always be visible, i.e. cause a failure. If it's not visible, such code fails silently and can be very difficult to debug.
		def fail!(exception = false, propagate = true)
			@status = :failed
			@result = exception
			
			if exception
				if propagate
					raise exception
				elsif @finished.nil?
					# If no one has called wait, we log this as a warning:
					Console.logger.warn(self, "Task may have ended with unhandled exception.", exception)
				else
					Console.logger.debug(self, exception)
				end
			end
		end
		
		def stop!
			# Console.logger.info(self, self.annotation) {"Task was stopped with #{@children&.size.inspect} children!"}
			@status = :stopped
			
			stop_children(true)
		end
		
		def schedule(&block)
			@fiber = Fiber.new do
				set!
				
				begin
					@result = yield
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
		
		# Finish the current task, moving any children to the parent.
		def finish!
			# Allow the fiber to be recycled.
			@fiber = nil
			
			# Attempt to remove this node from the task tree.
			consume
			
			# If this task was being used as a future, signal completion here:
			if @finished
				@finished.signal(self)
			end
		end
		
		# Set the current fiber's `:async_task` to this task.
		def set!
			# This is actually fiber-local:
			Thread.current[:async_task] = self
		end
	end
end
