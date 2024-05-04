# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2024, by Samuel Williams.
# Copyright, 2020, by Jun Jiang.
# Copyright, 2021, by Julien Portalier.

require_relative 'clock'
require_relative 'task'

require 'io/event'

require 'console'
require 'timers'
require 'resolv'

module Async
	# Handles scheduling of fibers. Implements the fiber scheduler interface.
	class Scheduler < Node
		class ClosedError < RuntimeError
			def initialize(message = "Scheduler is closed!")
				super
			end
		end
		
		# Whether the fiber scheduler is supported.
		# @public Since `stable-v1`.
		def self.supported?
			true
		end
		
		def initialize(parent = nil, selector: nil)
			super(parent)
			
			@selector = selector || ::IO::Event::Selector.new(Fiber.current)
			@interrupted = false
			
			@blocked = 0
			
			@busy_time = 0.0
			@idle_time = 0.0
			
			@timers = ::Timers::Group.new
		end
		
		# Compute the scheduler load according to the busy and idle times that are updated by the run loop.
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
		
		def scheduler_close
			# If the execution context (thread) was handling an exception, we want to exit as quickly as possible:
			unless $!
				self.run
			end
		ensure
			self.close
		end
		
		# Terminate the scheduler. We deliberately ignore interrupts here, as this code can be called from an interrupt, and we don't want to be interrupted while cleaning up.
		def terminate
			Thread.handle_interrupt(::Interrupt => :never) do
				super
			end
		end
		
		# @public Since `stable-v1`.
		def close
			# It's critical to stop all tasks. Otherwise they might be holding on to resources which are never closed/released correctly.
			until self.terminate
				self.run_once!
			end
			
			Kernel.raise "Closing scheduler with blocked operations!" if @blocked > 0
			
			# We depend on GVL for consistency:
			# @guard.synchronize do
			
			# We want `@selector = nil` to be a visible side effect from this point forward, specifically in `#interrupt` and `#unblock`. If the selector is closed, then we don't want to push any fibers to it.
			selector = @selector
			@selector = nil
			
			selector&.close
			
			# end
			
			consume
		end
		
		# @returns [Boolean] Whether the scheduler has been closed.
		# @public Since `stable-v1`.
		def closed?
			@selector.nil?
		end
		
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
		
		def raise(*arguments)
			@selector.raise(*arguments)
		end
		
		def resume(fiber, *arguments)
			@selector.resume(fiber, *arguments)
		end
		
		# Invoked when a fiber tries to perform a blocking operation which cannot continue. A corresponding call {unblock} must be performed to allow this fiber to continue.
		# @asynchronous May only be called on same thread as fiber scheduler.
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
			timer&.cancel
		end
		
		# @asynchronous May be called from any thread.
		def unblock(blocker, fiber)
			# $stderr.puts "unblock(#{blocker}, #{fiber})"
			
			# This operation is protected by the GVL:
			if selector = @selector
				selector.push(fiber)
				selector.wakeup
			end
		end
		
		# @asynchronous May be non-blocking..
		def kernel_sleep(duration = nil)
			if duration
				self.block(nil, duration)
			else
				self.transfer
			end
		end
		
		# @asynchronous May be non-blocking..
		def address_resolve(hostname)
			# On some platforms, hostnames may contain a device-specific suffix (e.g. %en0). We need to strip this before resolving.
			# See <https://github.com/socketry/async/issues/180> for more details.
			hostname = hostname.split("%", 2).first
			::Resolv.getaddresses(hostname)
		end
		
		
		if IO.method_defined?(:timeout)
			private def get_timeout(io)
				io.timeout
			end
		else
			private def get_timeout(io)
				nil
			end
		end
		
		# @asynchronous May be non-blocking..
		def io_wait(io, events, timeout = nil)
			fiber = Fiber.current
			
			if timeout
				# If an explicit timeout is specified, we expect that the user will handle it themselves:
				timer = @timers.after(timeout) do
					fiber.transfer
				end
			elsif timeout = get_timeout(io)
				# Otherwise, if we default to the io's timeout, we raise an exception:
				timer = @timers.after(timeout) do
					fiber.raise(::IO::TimeoutError, "Timeout while waiting for IO to become ready!")
				end
			end
			
			return @selector.io_wait(fiber, io, events)
		ensure
			timer&.cancel
		end
		
		if ::IO::Event::Support.buffer?
			def io_read(io, buffer, length, offset = 0)
				fiber = Fiber.current
				
				if timeout = get_timeout(io)
					timer = @timers.after(timeout) do
						fiber.raise(::IO::TimeoutError, "Timeout while waiting for IO to become readable!")
					end
				end
				
				@selector.io_read(fiber, io, buffer, length, offset)
			ensure
				timer&.cancel
			end
			
			if RUBY_ENGINE != "ruby" || RUBY_VERSION >= "3.3.1"
				def io_write(io, buffer, length, offset = 0)
					fiber = Fiber.current
					
					if timeout = get_timeout(io)
						timer = @timers.after(timeout) do
							fiber.raise(::IO::TimeoutError, "Timeout while waiting for IO to become writable!")
						end
					end
					
					@selector.io_write(fiber, io, buffer, length, offset)
				ensure
					timer&.cancel
				end
			end
		end
		
		# Wait for the specified process ID to exit.
		# @parameter pid [Integer] The process ID to wait for.
		# @parameter flags [Integer] A bit-mask of flags suitable for `Process::Status.wait`.
		# @returns [Process::Status] A process status instance.
		# @asynchronous May be non-blocking..
		def process_wait(pid, flags)
			return @selector.process_wait(Fiber.current, pid, flags)
		end
		
		# Run one iteration of the event loop.
		# Does not handle interrupts.
		# @parameter timeout [Float | Nil] The maximum timeout, or if nil, indefinite.
		# @returns [Boolean] Whether there is more work to do.
		def run_once(timeout = nil)
			Kernel::raise "Running scheduler on non-blocking fiber!" unless Fiber.blocking?
			
			# If we are finished, we stop the task tree and exit:
			if self.finished?
				return false
			end
			
			return run_once!(timeout)
		end
		
		# Run one iteration of the event loop.
		#
		# When terminating the event loop, we already know we are finished. So we don't need to check the task tree. This is a logical requirement because `run_once` ignores transient tasks. For example, a single top level transient task is not enough to keep the reactor running, but during termination we must still process it in order to terminate child tasks.
		#
		# @parameter timeout [Float | Nil] The maximum timeout, or if nil, indefinite.
		# @returns [Boolean] Whether there is more work to do.
		private def run_once!(timeout = 0)
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
		
		# Checks and clears the interrupted state of the scheduler.
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
		
		# Run the reactor until all tasks are finished. Proxies arguments to {#async} immediately before entering the loop, if a block is provided.
		def run(...)
			Kernel::raise ClosedError if @selector.nil?
			
			initial_task = self.async(...) if block_given?
			
			begin
				# In theory, we could use Exception here to be a little bit safer, but we've only shown the case for SignalException to be a problem, so let's not over-engineer this.
				Thread.handle_interrupt(::SignalException => :never) do
					while true
						# If we are interrupted, we need to exit:
						break if self.interrupted?
						
						# If we are finished, we need to exit:
						break unless self.run_once
					end
				end
			rescue Interrupt
				Thread.handle_interrupt(::SignalException => :never) do
					self.stop
				end
				
				retry
			end
				
			return initial_task
		ensure
			Console.debug(self) {"Exiting run-loop because #{$! ? $! : 'finished'}."}
		end
		
		# Start an asynchronous task within the specified reactor. The task will be
		# executed until the first blocking call, at which point it will yield and
		# and this method will return.
		#
		# This is the main entry point for scheduling asynchronus tasks.
		#
		# @yields {|task| ...} Executed within the task.
		# @returns [Task] The task that was scheduled into the reactor.
		# @deprecated With no replacement.
		def async(*arguments, **options, &block)
			Kernel::raise ClosedError if @selector.nil?
			
			task = Task.new(Task.current? || self, **options, &block)
			
			# I want to take a moment to explain the logic of this.
			# When calling an async block, we deterministically execute it until the
			# first blocking operation. We don't *have* to do this - we could schedule
			# it for later execution, but it's useful to:
			# - Fail at the point of the method call where possible.
			# - Execute determinstically where possible.
			# - Avoid scheduler overhead if no blocking operation is performed.
			task.run(*arguments)
			
			# Console.debug "Initial execution of task #{fiber} complete (#{result} -> #{fiber.alive?})..."
			return task
		end
		
		def fiber(...)
			return async(...).fiber
		end
		
		# Invoke the block, but after the specified timeout, raise {TimeoutError} in any currenly blocking operation. If the block runs to completion before the timeout occurs or there are no non-blocking operations after the timeout expires, the code will complete without any exception.
		# @parameter duration [Numeric] The time in seconds, in which the task should complete.
		def with_timeout(duration, exception = TimeoutError, message = "execution expired", &block)
			fiber = Fiber.current
			
			timer = @timers.after(duration) do
				if fiber.alive?
					fiber.raise(exception, message)
				end
			end
			
			yield timer
		ensure
			timer.cancel if timer
		end
		
		def timeout_after(duration, exception, message, &block)
			with_timeout(duration, exception, message) do |timer|
				yield duration
			end
		end
	end
end
