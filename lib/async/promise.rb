# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

require_relative "error"
require_relative "deadline"
require_relative "cancel"

module Async
	# A promise represents a value that will be available in the future.
	# Unlike Condition, once resolved (or rejected), all future waits return immediately 
	# with the stored value or raise the stored exception.
	# 
	# This is thread-safe and integrates with the fiber scheduler.
	#
	# @public Since *Async v2*.
	class Promise
		# Create a new promise.
		def initialize
			# nil = pending, :completed = success, :failed = failure, :cancelled = cancelled:
			@resolved = nil
			
			# Stores either the result value or the exception:
			@value = nil
			
			# Track how many fibers are currently waiting:
			@waiting = 0
			
			@mutex = Mutex.new
			@condition = ConditionVariable.new
		end
		
		# @returns [Boolean] Whether the promise has been resolved or rejected.
		def resolved?
			@mutex.synchronize{!!@resolved}
		end
		
		# @returns [Symbol | Nil] The internal resolved state (:completed, :failed, :cancelled, or nil if pending).
		# @private For internal use by Task.
		def resolved
			@mutex.synchronize{@resolved}
		end
		
		# @returns [Boolean] Whether the promise has been cancelled.
		def cancelled?
			@mutex.synchronize{@resolved == :cancelled}
		end
		
		# @returns [Boolean] Whether the promise failed with an exception.
		def failed?
			@mutex.synchronize{@resolved == :failed}
		end
		
		# @returns [Boolean] Whether the promise has completed successfully.
		def completed?
			@mutex.synchronize{@resolved == :completed}
		end
		
		# @returns [Boolean] Whether any fibers are currently waiting for this promise.
		def waiting?
			@mutex.synchronize{@waiting > 0}
		end
		
		# Artificially mark that someone is waiting (useful for suppressing warnings).
		# @private Internal use only.
		def suppress_warnings!
			@mutex.synchronize{@waiting += 1}
		end
		
		# Non-blocking access to the current value. Returns nil if not yet resolved.
		# Does not raise exceptions even if the promise was rejected or cancelled.
		# For resolved promises, returns the raw stored value (result, exception, or cancel exception).
		#
		# @returns [Object | Nil] The stored value, or nil if pending.
		def value
			@mutex.synchronize{@resolved ? @value : nil}
		end
		
		# Wait indefinitely for the promise to be resolved.
		private def wait_indefinitely
			until @resolved
				@condition.wait(@mutex)
			end
		end
		
		# Wait for the promise to be resolved, respecting the deadline timeout.
		# @parameter timeout [Numeric] The timeout duration.
		# @returns [Boolean] True if resolved, false if timeout expires.
		private def wait_with_timeout(timeout)
			# Create deadline for timeout tracking:
			deadline = Deadline.start(timeout)
			
			# Handle immediate timeout (non-blocking):
			if deadline == Deadline::Zero && !@resolved
				return false
			end
			
			# Wait with deadline tracking:
			until @resolved
				# Get remaining time for this wait iteration:
				remaining = deadline.remaining
				
				# Check if deadline has expired before waiting:
				if remaining <= 0
					return false
				end
				
				@condition.wait(@mutex, remaining)
			end
			
			return true
		end
		
		# Wait for the promise to be resolved (without raising exceptions).
		#
		# If already resolved, returns immediately. Otherwise, waits until resolution or timeout.
		#
		# @parameter timeout [Numeric | Nil] Maximum time to wait. If nil, waits indefinitely. If 0, returns immediately if not resolved.
		# @returns [Boolean] True if the promise is resolved, false if timeout expires
		def wait?(timeout: nil)
			unless @resolved
				@mutex.synchronize do
					# Increment waiting count:
					@waiting += 1
					
					begin
						# Wait for resolution if not already resolved:
						unless @resolved
							if timeout.nil?
								wait_indefinitely
							else
								unless wait_with_timeout(timeout)
									# We don't want to race on @resolved after exiting the mutex:
									return nil
								end
							end
						end
					ensure
						# Decrement waiting count when done:
						@waiting -= 1
					end
				end
			end
			
			return @resolved
		end
		
		# Wait for the promise to be resolved and return the value.
		#
		# If already resolved, returns immediately. If rejected, raises the stored exception.
		#
		# @returns [Object] The resolved value.
		# @raises [Exception] The rejected or cancelled exception.
		# @raises [Async::TimeoutError] If timeout expires before the promise is resolved.
		def wait(...)
			resolved = wait?(...)
			
			if resolved.nil?
				raise TimeoutError, "Timeout while waiting for promise!"
			elsif resolved == :completed
				return @value
			elsif @value
				# If we aren't completed, we should have an exception or cancel reason stored:
				raise @value
			end
		end
		
		# Resolve the promise with a value.
		# All current and future waiters will receive this value.
		# Can only be called once - subsequent calls are ignored.
		#
		# @parameter value [Object] The value to resolve the promise with.
		def resolve(value)
			@mutex.synchronize do
				return if @resolved
				
				@resolved = :completed
				@value = value
				
				# Wake up all waiting fibers:
				@condition.broadcast
			end
			
			return value
		end
		
		# Reject the promise with an exception.
		# All current and future waiters will receive this exception.
		# Can only be called once - subsequent calls are ignored.
		#
		# @parameter exception [Exception] The exception to reject the promise with.
		def reject(exception)
			@mutex.synchronize do
				return if @resolved
				
				@resolved = :failed
				@value = exception
				
				# Wake up all waiting fibers:
				@condition.broadcast
			end
			
			return nil
		end
		
		# Cancel the promise, indicating cancellation.
		# All current and future waiters will receive nil.
		# Can only be called on pending promises - no-op if already resolved.
		def cancel(exception = Cancel.new("Promise cancelled!"))
			@mutex.synchronize do
				# No-op if already in any final state
				return if @resolved
				
				@resolved = :cancelled
				@value = exception
				
				# Wake up all waiting fibers:
				@condition.broadcast
			end
			
			return nil
		end
		
		# Resolve the promise with the result of the block.
		# If the block raises an exception, the promise will be rejected.
		# If the promise was already resolved, the block will not be called.
		# @yields {...} The block to call to resolve the promise.
		# @returns [Object] The result of the block.
		def fulfill(&block)
			raise "Promise already resolved!" if @resolved
			
			begin
				return self.resolve(yield)
			rescue Cancel => exception
				return self.cancel(exception)
			rescue => error
				return self.reject(error)
			rescue Exception => exception
				self.reject(exception)
				raise
			ensure
				# Handle non-local exits (throw, etc.) that bypass normal flow:
				self.resolve(nil) unless @resolved
			end
		end
		
		# If a promise is given, fulfill it with the result of the block.
		# If no promise is given, simply yield to the block.
		# This is useful for methods that may optionally take a promise to fulfill.
		# @parameter promise [Promise | Nil] The optional promise to fulfill.
		# @yields {...} The block to call to resolve the promise or return a value.
		# @returns [Object] The result of the block.
		def self.fulfill(promise, &block)
			if promise
				return promise.fulfill(&block)
			else
				return yield
			end
		end
	end
end
