# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2026, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2017, by Devin Christensen.
# Copyright, 2020, by Patrik Wenger.
# Copyright, 2023, by Math Ieu.
# Copyright, 2025, by Shigeru Nakajima.
# Copyright, 2025-2026, by Shopify Inc.

require "fiber"
require "console"

require_relative "node"
require_relative "condition"
require_relative "error"
require_relative "promise"
require_relative "stop"

Fiber.attr_accessor :async_task

module Async
	# Represents a sequential unit of work, defined by a block, which is executed concurrently with other tasks. A task can be in one of the following states: `initialized`, `running`, `completed`, `failed`, or `cancelled`.
	#
	# ```mermaid
	# stateDiagram-v2
	# [*] --> Initialized
	# Initialized --> Running : Run
	#
	# Running --> Completed : Return Value
	# Running --> Failed : Exception
	#
	# Completed --> [*]
	# Failed --> [*]
	#
	# Running --> Cancelled : Cancel
	# Cancelled --> [*]
	# Completed --> Cancelled : Cancel
	# Failed --> Cancelled : Cancel
	# Initialized --> Cancelled : Cancel
	# ```
	#
	# @example Creating a task that sleeps for 1 second.
	# 	require "async"
	# 	Async do |task|
	# 		sleep(1)
	# 	end
	#
	# @public Since *Async v1*.
	class Task < Node
		# Raised when a child task is created within a task that has finished execution.
		class FinishedError < RuntimeError
			# Create a new finished error.
			#
			# @parameter message [String] The error message.
			def initialize(message = "Cannot create child task within a task that has finished execution!")
				super
			end
		end
		
		# @deprecated With no replacement.
		def self.yield
			warn("`Async::Task.yield` is deprecated with no replacement.", uplevel: 1, category: :deprecated) if $VERBOSE
			
			Fiber.scheduler.transfer
		end
		
		# Run the given block of code in a task, asynchronously, in the given scheduler.
		def self.run(scheduler, *arguments, **options, &block)
			self.new(scheduler, **options, &block).tap do |task|
				task.run(*arguments)
			end
		end
		
		# Create a new task.
		# @parameter reactor [Reactor] the reactor this task will run within.
		# @parameter parent [Task] the parent task.
		def initialize(parent = Task.current?, finished: nil, **options, &block)
			# These instance variables are critical to the state of the task.
			# In the initialized state, the @block should be set, but the @fiber should be nil.
			# In the running state, the @fiber should be set, and @block should be nil.
			# In a finished state, the @block should be nil, and the @fiber should be nil.
			@block = block
			@fiber = nil
			
			@promise = Promise.new
			
			# Handle finished: parameter for backward compatibility:
			case finished
			when false
				# `finished: false` suppresses warnings for expected task failures:
				@promise.suppress_warnings!
			when nil
				# `finished: nil` is the default, no special handling:
			else
				# All other `finished:` values are deprecated:
				warn("finished: argument with non-false value is deprecated and will be removed.", uplevel: 1, category: :deprecated) if $VERBOSE
			end
			
			@defer_cancel = nil
			
			# Call this after all state is initialized, as it may call `add_child` which will set the parent and make it visible to the scheduler.
			super(parent, **options)
		end
		
		# @returns [Scheduler] The scheduler for this task.
		def reactor
			self.root
		end
		
		# @returns [Array(Thread::Backtrace::Location) | Nil] The backtrace of the task, if available.
		def backtrace(*arguments)
			@fiber&.backtrace(*arguments)
		end
		
		# Annotate the task with a description.
		#
		# This will internally try to annotate the fiber if it is running, otherwise it will annotate the task itself.
		#
		# @parameter annotation [String] The description to annotate the task with.
		def annotate(annotation, &block)
			if @fiber
				@fiber.annotate(annotation, &block)
			else
				super
			end
		end
		
		# @returns [Object] The annotation of the task.
		def annotation
			if @fiber
				@fiber.annotation
			else
				super
			end
		end
		
		# @returns [String] A description of the task and it's current status.
		def to_s
			"\#<#{self.description} (#{self.status})>"
		end
		
		# @deprecated Prefer {Kernel#sleep} except when compatibility with `stable-v1` is required.
		def sleep(duration = nil)
			Kernel.warn("`Async::Task#sleep` is deprecated, use `Kernel#sleep` instead.", uplevel: 1, category: :deprecated) if $VERBOSE
			
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
		
		# @attribute [Fiber] The fiber which is being used for the execution of this task.
		attr :fiber
		
		# @returns [Boolean] Whether the internal fiber is alive, i.e. it is actively executing.
		def alive?
			@fiber&.alive?
		end
		
		# Whether we can remove this node from the reactor graph.
		# @returns [Boolean]
		def finished?
			# If the block is nil and the fiber is nil, it means the task has finished execution. This becomes true after `finish!` is called.
			super && @block.nil? && @fiber.nil?
		end
		
		# @returns [Boolean] Whether the task is running.
		def running?
			self.alive?
		end
		
		# @returns [Boolean] Whether the task failed with an exception.
		def failed?
			@promise.failed?
		end
		
		# @returns [Boolean] Whether the task has been cancelled.
		def cancelled?
			@promise.cancelled?
		end
		
		# @returns [Boolean] Whether the task has completed execution and generated a result.
		def completed?
			@promise.completed?
		end
		
		# Alias for {#completed?}.
		def complete?
			self.completed?
		end
		
		# @attribute [Symbol] The status of the execution of the task, one of `:initialized`, `:running`, `:complete`, `:cancelled` or `:failed`.
		def status
			case @promise.resolved
			when :cancelled
				:cancelled
			when :failed
				:failed
			when :completed
				:completed
			when nil
				self.running? ? :running : :initialized
			end
		end
		
		# Begin the execution of the task.
		#
		# @raises [RuntimeError] If the task is already running.
		def run(*arguments)
			# Move from initialized to running by clearing @block
			if block = @block
				@block = nil
				
				schedule do
					block.call(self, *arguments)
				rescue => error
					# I'm not completely happy with this overhead, but the alternative is to not log anything which makes debugging extremely difficult. Maybe we can introduce a debug wrapper which adds extra logging.
					unless @promise.waiting?
						warn(self, "Task may have ended with unhandled exception.", exception: error)
					end
					
					raise
				end
			else
				raise RuntimeError, "Task already running!"
			end
		end
		
		# Run an asynchronous task as a child of the current task.
		#
		# @public Since *Async v1*.
		# @asynchronous May context switch immediately to the new task.
		#
		# @yields {|task| ...} in the context of the new task.
		# @raises [FinishedError] If the task has already finished.
		# @returns [Task] The child task.
		def async(*arguments, **options, &block)
			raise FinishedError if self.finished?
			
			task = Task.new(self, **options, &block)
			
			# When calling an async block, we deterministically execute it until the first blocking operation. We don't *have* to do this - we could schedule it for later execution, but it's useful to:
			#
			# - Fail at the point of the method call where possible.
			# - Execute determinstically where possible.
			# - Avoid scheduler overhead if no blocking operation is performed.
			#
			# There are different strategies (greedy vs non-greedy). We are currently using a greedy strategy.
			task.run(*arguments)
			
			return task
		end
		
		# Retrieve the current result of the task. Will cause the caller to wait until result is available. If the task resulted in an unhandled error (derived from `StandardError`), this will be raised. If the task was cancelled, this will return `nil`.
		#
		# Conceptually speaking, waiting on a task should return a result, and if it throws an exception, this is certainly an exceptional case that should represent a failure in your program, not an expected outcome. In other words, you should not design your programs to expect exceptions from `#wait` as a normal flow control, and prefer to catch known exceptions within the task itself and return a result that captures the intention of the failure, e.g. a `TimeoutError` might simply return `nil` or `false` to indicate that the operation did not generate a valid result (as a timeout was an expected outcome of the internal operation in this case).
		#
		# @parameter timeout [Numeric] The maximum number of seconds to wait for the result before raising a `TimeoutError`, if specified.
		# @raises [RuntimeError] If the task's fiber is the current fiber.
		# @returns [Object] The final expression/result of the task's block.
		# @asynchronous This method is thread-safe.
		def wait(...)
			raise "Cannot wait on own fiber!" if Fiber.current.equal?(@fiber)
			
			# Wait for the task to complete:
			@promise.wait(...)
		end
		
		# For compatibility with `Thread#join` and similar interfaces.
		alias join wait
		
		# Wait on all non-transient children to complete, recursively, then wait on the task itself, if it is not the current task.
		#
		# If any child task fails with an exception, that exception will be raised immediately, and remaining children may not be waited on.
		#
		# @example Waiting on all children.
		# 	Async do |task|
		# 		child = task.async do
		# 			sleep(0.01)
		# 		end
		# 		task.wait_all # Will wait on the child task.
		# 	end
		#
		# @raises [StandardError] If any child task failed with an exception, that exception will be raised.
		# @returns [Object | Nil] The final expression/result of the task's block, or nil if called from within the task.
		# @asynchronous This method is thread-safe.
		def wait_all
			@children&.each do |child|
				# Skip transient tasks
				next if child.transient?
				
				child.wait_all
			end
			
			# Only wait on the task if we're not waiting on ourselves:
			unless self.current?
				return self.wait
			end
		end
		
		# Access the result of the task without waiting. May be nil if the task is not completed. Does not raise exceptions.
		def result
			value = @promise.value
			
			# For backward compatibility, return nil for cancelled tasks:
			if @promise.cancelled?
				nil
			else
				value
			end
		end
		
		# Cancel the task and all of its children.
		#
		# If `later` is false, it means that `cancel` has been invoked directly. When `later` is true, it means that `cancel` is invoked by `stop_children` or some other indirect mechanism. In that case, if we encounter the "current" fiber, we can't cancel it right away, as it's currently performing `#cancel`. Cancelling it immediately would interrupt the current cancel traversal, so we need to schedule the cancel to occur later.
		#
		# @parameter later [Boolean] Whether to cancel the task later, or immediately.
		# @parameter cause [Exception] The cause of the cancel operation.
		def cancel(later = false, cause: $!)
			# If no cause is given, we generate one from the current call stack:
			unless cause
				cause = Cancel::Cause.for("Cancelling task!")
			end
			
			if self.cancelled?
				# If the task is already cancelled, a `cancel` state transition re-enters the same state which is a no-op. However, we will also attempt to cancel any running children too. This can happen if the children did not cancel correctly the first time around. Doing this should probably be considered a bug, but it's better to be safe than sorry.
				return cancelled!
			end
			
			# If the fiber is alive, we need to cancel it:
			if @fiber&.alive?
				# As the task is now exiting, we want to ensure the event loop continues to execute until the task finishes.
				self.transient = false
				
				# If we are deferring cancel...
				if @defer_cancel == false
					# Don't cancel now... but update the state so we know we need to cancel later.
					@defer_cancel = cause
					return false
				end
				
				if self.current?
					# If the fiber is current, and later is `true`, we need to schedule the fiber to be cancelled later, as it's currently invoking `cancel`:
					if later
						# If the fiber is the current fiber and we want to cancel it later, schedule it:
						Fiber.scheduler.push(Cancel::Later.new(self, cause))
					else
						# Otherwise, raise the exception directly:
						raise Cancel, "Cancelling current task!", cause: cause
					end
				else
					# If the fiber is not curent, we can raise the exception directly:
					begin
						# There is a chance that this will cancel the fiber that originally called cancel. If that happens, the exception handling in `#cancelled` will rescue the exception and re-raise it later.
						Fiber.scheduler.raise(@fiber, Cancel, cause: cause)
					rescue FiberError
						# In some cases, this can cause a FiberError (it might be resumed already), so we schedule it to be cancelled later:
						Fiber.scheduler.push(Cancel::Later.new(self, cause))
					end
				end
			else
				# We are not running, but children might be, so transition directly into cancelled state:
				cancel!
			end
		end
		
		# Defer the handling of cancel. During the execution of the given block, if a cancel is requested, it will be deferred until the block exits. This is useful for ensuring graceful shutdown of servers and other long-running tasks. You should wrap the response handling code in a defer_cancel block to ensure that the task is cancelled when the response is complete but not before.
		#
		# You can nest calls to defer_cancel, but the cancel will only be deferred until the outermost block exits.
		#
		# If cancel is invoked a second time, it will be immediately executed.
		#
		# @yields {} The block of code to execute.
		# @public Since *Async v1*.
		def defer_cancel
			# Tri-state variable for controlling cancel:
			# - nil: defer_cancel has not been called.
			# - false: defer_cancel has been called and we are not cancelling.
			# - true: defer_cancel has been called and we will cancel when exiting the block.
			if @defer_cancel.nil?
				begin
					# If we are not deferring cancel already, we can defer it now:
					@defer_cancel = false
					
					yield
				rescue Cancel
					# If we are exiting due to a cancel, we shouldn't try to invoke cancel again:
					@defer_cancel = nil
					raise
				ensure
					defer_cancel = @defer_cancel
					
					# We need to ensure the state is reset before we exit the block:
					@defer_cancel = nil
					
					# If we were asked to cancel, we should do so now:
					if defer_cancel
						raise Cancel, "Cancelling current task (was deferred)!", cause: defer_cancel
					end
				end
			else
				# If we are deferring cancel already, entering it again is a no-op.
				yield
			end
		end
		
		# Backward compatibility alias for {#defer_cancel}.
		# @deprecated Use {#defer_cancel} instead.
		def defer_stop(&block)
			defer_cancel(&block)
		end
		
		# @returns [Boolean] Whether cancel has been deferred.
		def cancel_deferred?
			!!@defer_cancel
		end
		
		# Backward compatibility alias for {#cancel_deferred?}.
		# @deprecated Use {#cancel_deferred?} instead.
		def stop_deferred?
			cancel_deferred?
		end
		
		# Lookup the {Task} for the current fiber. Raise `RuntimeError` if none is available.
		# @returns [Task]
		# @raises[RuntimeError] If task was not {set!} for the current fiber.
		def self.current
			Fiber.current.async_task or raise RuntimeError, "No async task available!"
		end
		
		# Check if there is a task defined for the current fiber.
		# @returns [Interface(:async) | Nil]
		def self.current?
			Fiber.current.async_task
		end
		
		# @returns [Boolean] Whether this task is the currently executing task.
		def current?
			Fiber.current.equal?(@fiber)
		end
		
		private
		
		def warn(...)
			Console.warn(...)
		end
		
		# Finish the current task, moving any children to the parent.
		def finish!
			# Don't hold references to the fiber or block after the task has finished:
			@fiber = nil
			@block = nil # If some how we went directly from initialized to finished.
			
			# Attempt to remove this node from the task tree.
			consume
		end
		
		# State transition into the completed state.
		def completed!(result)
			# Resolve the promise with the result:
			@promise.resolve(result)
		end
		
		# State transition into the failed state.
		def failed!(exception = false)
			# Reject the promise with the exception:
			@promise.reject(exception)
		end
		
		def cancelled!
			# Console.info(self, status:) {"Task #{self} was cancelled with #{@children&.size.inspect} children!"}
			
			# Cancel the promise, specify nil here so that no exception is raised when waiting on the promise:
			@promise.cancel(nil)
			
			cancelled = false
			
			begin
				# We are not running, but children might be so we should stop them:
				stop_children(true)
			rescue Cancel
				cancelled = true
				# If we are cancelling children, and one of them tries to cancel the current task, we should ignore it. We will be cancelled later.
				retry
			end
			
			if cancelled
				raise Cancel, "Cancelling current task!"
			end
		end
		
		def stopped!
			cancelled!
		end
		
		def cancel!
			cancelled!
			
			finish!
		end
		
		def stop!
			cancel!
		end
		
		def schedule(&block)
			@fiber = Fiber.new(annotation: self.annotation) do
				begin
					completed!(yield)
				rescue Cancel
					cancelled!
				rescue StandardError => error
					failed!(error)
				rescue Exception => exception
					failed!(exception)
					
					# This is a critical failure, we should stop the reactor:
					raise
				ensure
					# Console.info(self) {"Task ensure $! = #{$!} with #{@children&.size.inspect} children!"}
					finish!
				end
			end
			
			@fiber.async_task = self
			
			(Fiber.scheduler || self.reactor).resume(@fiber)
		end
	end
end
