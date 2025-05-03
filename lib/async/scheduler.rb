# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.
# Copyright, 2020, by Jun Jiang.
# Copyright, 2021, by Julien Portalier.

require_relative "clock"
require_relative "task"
require_relative "timeout"
require_relative "worker_pool"

require "io/event"

require "console"
require "resolv"

module Async
	begin
		require "fiber/profiler"
		Profiler = Fiber::Profiler
	rescue LoadError
		# Fiber::Profiler is not available.
		Profiler = nil
	end
	
	# Handles scheduling of fibers. Implements the fiber scheduler interface.
	class Scheduler < Node
		WORKER_POOL = ENV.fetch("ASYNC_SCHEDULER_WORKER_POOL", nil).then do |value|
			value == "true" ? true : nil
		end
		
		# Raised when an operation is attempted on a closed scheduler.
		class ClosedError < RuntimeError
			# Create a new error.
			#
			# @parameter message [String] The error message.
			def initialize(message = "Scheduler is closed!")
				super
			end
		end
		
		# Whether the fiber scheduler is supported.
		# @public Since *Async v1*.
		def self.supported?
			true
		end
		
		# Create a new scheduler.
		#
		# @public Since *Async v1*.
		# @parameter parent [Node | Nil] The parent node to use for task hierarchy.
		# @parameter selector [IO::Event::Selector] The selector to use for event handling.
		def initialize(parent = nil, selector: nil, profiler: Profiler&.default, worker_pool: WORKER_POOL)
			super(parent)
			
			@selector = selector || ::IO::Event::Selector.new(Fiber.current)
			@profiler = profiler
			
			@interrupted = false
			
			@blocked = 0
			
			@busy_time = 0.0
			@idle_time = 0.0
			
			@timers = ::IO::Event::Timers.new
			if worker_pool == true
				@worker_pool = WorkerPool.new
			else
				@worker_pool = worker_pool
			end
			
			if @worker_pool
				self.singleton_class.prepend(WorkerPool::BlockingOperationWait)
			end
		end
		
		# Compute the scheduler load according to the busy and idle times that are updated by the run loop.
		#
		# @returns [Float] The load of the scheduler. 0.0 means no load, 1.0 means fully loaded or over-loaded.
		def load
			total_time = @busy_time + @idle_time
			
			# If the total time is zero, then the load is zero:
			return 0.0 if total_time.zero?
			
			# We normalize to a 1 second window:
			if total_time > 1.0
				ratio = 1.0 / total_time
				@busy_time *= ratio
				@idle_time *= ratio
				
				# We don't need to divide here as we've already normalised it to a 1s window:
				return @busy_time
			else
				return @busy_time / total_time
			end
		end
	
		# Invoked when the fiber scheduler is being closed.
		#
		# Executes the run loop until all tasks are finished, then closes the scheduler.
		def scheduler_close(error = $!)
			# If the execution context (thread) was handling an exception, we want to exit as quickly as possible:
			unless error
				self.run
			end
		ensure
			self.close
		end
		
		# Terminate all child tasks.
		def terminate
			# If that doesn't work, take more serious action:
			@children&.each do |child|
				child.terminate
			end
			
			return @children.nil?
		end
		
		# Terminate all child tasks and close the scheduler.
		# @public Since *Async v1*.
		def close
			self.run_loop do
				until self.terminate
					self.run_once!
				end
			end
			
			Kernel.raise "Closing scheduler with blocked operations!" if @blocked > 0
		ensure
			# We want `@selector = nil` to be a visible side effect from this point forward, specifically in `#interrupt` and `#unblock`. If the selector is closed, then we don't want to push any fibers to it.
			selector = @selector
			@selector = nil
			
			selector&.close
			
			worker_pool = @worker_pool
			@worker_pool = nil
			
			worker_pool&.close
			
			consume
		end
		
		# @returns [Boolean] Whether the scheduler has been closed.
		# @public Since *Async v1*.
		def closed?
			@selector.nil?
		end
		
		# @returns [String] A description of the scheduler.
		def to_s
			"\#<#{self.description} #{@children&.size || 0} children (#{stopped? ? 'stopped' : 'running'})>"
		end
		
		# Interrupt the event loop and cause it to exit.
		# @asynchronous May be called from any thread.
		def interrupt
			@interrupted = true
			@selector&.wakeup
		end
		
		# Transfer from the calling fiber to the event loop.
		def transfer
			@selector.transfer
		end
		
		# Yield the current fiber and resume it on the next iteration of the event loop.
		def yield
			@selector.yield
		end
		
		# Schedule a fiber (or equivalent object) to be resumed on the next loop through the reactor.
		# @parameter fiber [Fiber | Object] The object to be resumed on the next iteration of the run-loop.
		def push(fiber)
			@selector.push(fiber)
		end
		
		# Raise an exception on a specified fiber with the given arguments.
		#
		# This internally schedules the current fiber to be ready, before raising the exception, so that it will later resume execution.
		#
		# @parameter fiber [Fiber] The fiber to raise the exception on.
		# @parameter *arguments [Array] The arguments to pass to the fiber.
		def raise(...)
			@selector.raise(...)
		end
		
		# Resume execution of the specified fiber.
		#
		# @parameter fiber [Fiber] The fiber to resume.
		# @parameter arguments [Array] The arguments to pass to the fiber.
		def resume(fiber, *arguments)
			@selector.resume(fiber, *arguments)
		end
		
		# Invoked when a fiber tries to perform a blocking operation which cannot continue. A corresponding call {unblock} must be performed to allow this fiber to continue.
		#
		# @public Since *Async v2*.
		# @asynchronous May only be called on same thread as fiber scheduler.
		#
		# @parameter blocker [Object] The object that is blocking the fiber.
		# @parameter timeout [Float | Nil] The maximum time to block, or if nil, indefinitely.
		def block(blocker, timeout)
			# $stderr.puts "block(#{blocker}, #{Fiber.current}, #{timeout})"
			fiber = Fiber.current
			
			if timeout
				timer = @timers.after(timeout) do
					if fiber.alive?
						fiber.transfer(false)
					end
				end
			end
			
			begin
				@blocked += 1
				@selector.transfer
			ensure
				@blocked -= 1
			end
		ensure
			timer&.cancel!
		end
		
		# Unblock a fiber that was previously blocked.
		#
		# @public Since *Async v2* and *Ruby v3.1*.
		# @asynchronous May be called from any thread.
		#
		# @parameter blocker [Object] The object that was blocking the fiber.
		# @parameter fiber [Fiber] The fiber to unblock.
		def unblock(blocker, fiber)
			# $stderr.puts "unblock(#{blocker}, #{fiber})"
			
			# This operation is protected by the GVL:
			if selector = @selector
				selector.push(fiber)
				selector.wakeup
			end
		end
		
		# Sleep for the specified duration.
		#
		# @public Since *Async v2* and *Ruby v3.1*.
		# @asynchronous May be non-blocking.
		#
		# @parameter duration [Numeric | Nil] The time in seconds to sleep, or if nil, indefinitely.
		def kernel_sleep(duration = nil)
			if duration
				self.block(nil, duration)
			else
				self.transfer
			end
		end
		
		# Resolve the address of the given hostname.
		#
		# @public Since *Async v2*.
		# @asynchronous May be non-blocking.
		#
		# @parameter hostname [String] The hostname to resolve.
		def address_resolve(hostname)
			# On some platforms, hostnames may contain a device-specific suffix (e.g. %en0). We need to strip this before resolving.
			# See <https://github.com/socketry/async/issues/180> for more details.
			hostname = hostname.split("%", 2).first
			::Resolv.getaddresses(hostname)
		end
		
		# Wait for the specified IO to become ready for the specified events.
		#
		# @public Since *Async v2*.
		# @asynchronous May be non-blocking.
		#
		# @parameter io [IO] The IO object to wait on.
		# @parameter events [Integer] The events to wait for, e.g. `IO::READABLE`, `IO::WRITABLE`, etc.
		# @parameter timeout [Float | Nil] The maximum time to wait, or if nil, indefinitely.
		def io_wait(io, events, timeout = nil)
			fiber = Fiber.current
			
			if timeout
				# If an explicit timeout is specified, we expect that the user will handle it themselves:
				timer = @timers.after(timeout) do
					fiber.transfer
				end
			elsif timeout = io.timeout
				# Otherwise, if we default to the io's timeout, we raise an exception:
				timer = @timers.after(timeout) do
					fiber.raise(::IO::TimeoutError, "Timeout (#{timeout}s) while waiting for IO to become ready!")
				end
			end
			
			return @selector.io_wait(fiber, io, events)
		ensure
			timer&.cancel!
		end
		
		if ::IO::Event::Support.buffer?
			# Read from the specified IO into the buffer.
			#
			# @public Since *Async v2* and Ruby with `IO::Buffer` support.
			# @asynchronous May be non-blocking.
			#
			# @parameter io [IO] The IO object to read from.
			# @parameter buffer [IO::Buffer] The buffer to read into.
			# @parameter length [Integer] The minimum number of bytes to read.
			# @parameter offset [Integer] The offset within the buffer to read into.
			def io_read(io, buffer, length, offset = 0)
				fiber = Fiber.current
				
				if timeout = io.timeout
					timer = @timers.after(timeout) do
						fiber.raise(::IO::TimeoutError, "Timeout (#{timeout}s) while waiting for IO to become readable!")
					end
				end
				
				@selector.io_read(fiber, io, buffer, length, offset)
			ensure
				timer&.cancel!
			end
			
			if RUBY_ENGINE != "ruby" || RUBY_VERSION >= "3.3.1"
				# Write the specified buffer to the IO.
				#
				# @public Since *Async v2* and *Ruby v3.3.1* with `IO::Buffer` support.
				# @asynchronous May be non-blocking.
				#
				# @parameter io [IO] The IO object to write to.
				# @parameter buffer [IO::Buffer] The buffer to write from.
				# @parameter length [Integer] The minimum number of bytes to write.
				# @parameter offset [Integer] The offset within the buffer to write from.
				def io_write(io, buffer, length, offset = 0)
					fiber = Fiber.current
					
					if timeout = io.timeout
						timer = @timers.after(timeout) do
							fiber.raise(::IO::TimeoutError, "Timeout (#{timeout}s) while waiting for IO to become writable!")
						end
					end
					
					@selector.io_write(fiber, io, buffer, length, offset)
				ensure
					timer&.cancel!
				end
			end
		end
		
		# Wait for the specified process ID to exit.
		#
		# @public Since *Async v2*.
		# @asynchronous May be non-blocking.
		#
		# @parameter pid [Integer] The process ID to wait for.
		# @parameter flags [Integer] A bit-mask of flags suitable for `Process::Status.wait`.
		# @returns [Process::Status] A process status instance.
		# @asynchronous May be non-blocking..
		def process_wait(pid, flags)
			return @selector.process_wait(Fiber.current, pid, flags)
		end
		
		# Run one iteration of the event loop.
		#
		# When terminating the event loop, we already know we are finished. So we don't need to check the task tree. This is a logical requirement because `run_once` ignores transient tasks. For example, a single top level transient task is not enough to keep the reactor running, but during termination we must still process it in order to terminate child tasks.
		#
		# @parameter timeout [Float | Nil] The maximum timeout, or if nil, indefinite.
		# @returns [Boolean] Whether there is more work to do.
		private def run_once!(timeout = nil)
			start_time = Async::Clock.now
			
			interval = @timers.wait_interval
			
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
			
			begin
				@selector.select(interval)
			rescue Errno::EINTR
				# Ignore.
			end
			
			@timers.fire
			
			# Compute load:
			end_time = Async::Clock.now
			total_duration = end_time - start_time
			idle_duration = @selector.idle_duration
			busy_duration = total_duration - idle_duration
			
			@busy_time += busy_duration
			@idle_time += idle_duration
			
			# The reactor still has work to do:
			return true
		end
		
		# Run one iteration of the event loop.
		#
		# @public Since *Async v1*.
		# @asynchronous Must be invoked from blocking (root) fiber.
		#
		# @parameter timeout [Float | Nil] The maximum timeout, or if nil, indefinite.
		# @returns [Boolean] Whether there is more work to do.
		def run_once(timeout = nil)
			Kernel.raise "Running scheduler on non-blocking fiber!" unless Fiber.blocking?
			
			if self.finished?
				self.stop
			end
			
			# If we are finished, we stop the task tree and exit:
			if @children.nil?
				return false
			end
			
			return run_once!(timeout)
		end
		
		# Checks and clears the interrupted state of the scheduler.
		#
		# @returns [Boolean] Whether the reactor has been interrupted.
		private def interrupted?
			if @interrupted
				@interrupted = false
				return true
			end
			
			if Thread.pending_interrupt?
				return true
			end
			
			return false
		end
		
		# Stop all children, including transient children.
		#
		# @public Since *Async v1*.
		def stop
			@children&.each do |child|
				child.stop
			end
		end
		
		private def run_loop(&block)
			interrupt = nil
			
			begin
				# In theory, we could use Exception here to be a little bit safer, but we've only shown the case for SignalException to be a problem, so let's not over-engineer this.
				Thread.handle_interrupt(::SignalException => :never) do
					until self.interrupted?
						# If we are finished, we need to exit:
						break unless yield
					end
				end
			rescue Interrupt => interrupt
				# If an interrupt did occur during an iteration of the event loop, we need to handle it. More specifically, `self.stop` is not safe to interrupt without potentially corrupting the task tree.
				Thread.handle_interrupt(::SignalException => :never) do
					Console.debug(self) do |buffer|
						buffer.puts "Scheduler interrupted: #{interrupt.inspect}"
						self.print_hierarchy(buffer)
					end
					
					self.stop
				end
				
				retry
			end
			
			# If the event loop was interrupted, and we finished exiting normally (due to the interrupt), we need to re-raise the interrupt so that the caller can handle it too.
			if interrupt
				Kernel.raise(interrupt)
			end
		end
		
		# Run the reactor until all tasks are finished. Proxies arguments to {#async} immediately before entering the loop, if a block is provided.
		#
		# Forwards all parameters to {#async} if a block is given.
		#
		# @public Since *Async v1*.
		#
		# @yields {|task| ...} The top level task, if a block is given.
		# @returns [Task] The initial task that was scheduled into the reactor.
		def run(...)
			Kernel.raise ClosedError if @selector.nil?
			
			begin
				@profiler&.start
				
				initial_task = self.async(...) if block_given?
				
				self.run_loop do
					run_once
				end
				
				return initial_task
			ensure
				@profiler&.stop
			end
		end
		
		# Start an asynchronous task within the specified reactor. The task will be executed until the first blocking call, at which point it will yield and and this method will return.
		#
		# @public Since *Async v1*.
		# @asynchronous May context switch immediately to new task.
		# @deprecated Use {#run} or {Task#async} instead.
		#
		# @yields {|task| ...} Executed within the task.
		# @returns [Task] The task that was scheduled into the reactor.
		def async(*arguments, **options, &block)
			# warn "Async::Scheduler#async is deprecated. Use `run` or `Task#async` instead.", uplevel: 1, category: :deprecated
			
			Kernel.raise ClosedError if @selector.nil?
			
			task = Task.new(Task.current? || self, **options, &block)
			
			task.run(*arguments)
			
			return task
		end
		
		def fiber(...)
			return async(...).fiber
		end
		
		# Invoke the block, but after the specified timeout, raise {TimeoutError} in any currenly blocking operation. If the block runs to completion before the timeout occurs or there are no non-blocking operations after the timeout expires, the code will complete without any exception.
		#
		# @public Since *Async v1*.
		# @asynchronous May raise an exception at any interruption point (e.g. blocking operations).
		#
		# @parameter duration [Numeric] The time in seconds, in which the task should complete.
		# @parameter exception [Class] The exception class to raise.
		# @parameter message [String] The message to pass to the exception.
		# @yields {|timeout| ...} The block to execute with a timeout.
		def with_timeout(duration, exception = TimeoutError, message = "execution expired", &block)
			fiber = Fiber.current
			
			timer = @timers.after(duration) do
				if fiber.alive?
					fiber.raise(exception, message)
				end
			end
			
			if block.arity.zero?
				yield
			else
				yield Timeout.new(@timers, timer)
			end
		ensure
			timer&.cancel!
		end
		
		# Invoke the block, but after the specified timeout, raise the specified exception with the given message. If the block runs to completion before the timeout occurs or there are no non-blocking operations after the timeout expires, the code will complete without any exception.
		#
		# @public Since *Async v1* and *Ruby v3.1*. May be invoked from `Timeout.timeout`.
		# @asynchronous May raise an exception at any interruption point (e.g. blocking operations).
		#
		# @parameter duration [Numeric] The time in seconds, in which the task should complete.
		# @parameter exception [Class] The exception class to raise.
		# @parameter message [String] The message to pass to the exception.
		# @yields {|duration| ...} The block to execute with a timeout.
		def timeout_after(duration, exception, message, &block)
			with_timeout(duration, exception, message) do
				yield duration
			end
		end
	end
end
