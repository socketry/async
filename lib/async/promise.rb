# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

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
			# nil = pending, true = success, :error = failure:
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
			@mutex.synchronize { !!@resolved }
		end
		
		# @returns [Boolean] Whether any fibers are currently waiting for this promise.
		def waiting?
			@mutex.synchronize { @waiting > 0 }
		end
		
		# Artificially mark that someone is waiting (useful for suppressing warnings).
		# @private Internal use only.
		def suppress_warnings!
			@mutex.synchronize { @waiting += 1 }
		end
		
		# Non-blocking access to the current value. Returns nil if not yet resolved.
		# Does not raise exceptions even if the promise was rejected.
		#
		# @returns [Object | Nil] The resolved value, rejected exception, or nil if pending.
		def value
			@mutex.synchronize { @resolved ? @value : nil }
		end
		
		# Wait for the promise to be resolved and return the value.
		# If already resolved, returns immediately. If rejected, raises the stored exception.
		#
		# @returns [Object] The resolved value.
		# @raises [Exception] The rejected exception.
		def wait
			@mutex.synchronize do
				# Increment waiting count:
				@waiting += 1
				
				begin
					# Wait for resolution if not already resolved:
					@condition.wait(@mutex) unless @resolved
					
					# Return value or raise exception based on resolution type:
					if @resolved == :error
						raise @value
					else
						return @value
					end
				ensure
					# Decrement waiting count when done:
					@waiting -= 1
				end
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
				
				@value = value
				@resolved = true
				
				# Wake up all waiting fibers:
				@condition.broadcast
			end
		end
		
		# Reject the promise with an exception.
		# All current and future waiters will receive this exception.
		# Can only be called once - subsequent calls are ignored.
		#
		# @parameter exception [Exception] The exception to reject the promise with.
		def reject(exception)
			@mutex.synchronize do
				return if @resolved
				
				@value = exception
				@resolved = :error
				
				# Wake up all waiting fibers:
				@condition.broadcast
			end
		end
		
		# Resolve the promise with the result of the block.
		# If the block raises an exception, the promise will be rejected.
		# If the promise was already resolved, the block will not be called.
		# @yields {...} The block to call to resolve the promise.
		# @returns [Object] The result of the block.
		def fulfill(&block)
			raise "Promise already resolved!" if @resolved
			
			begin
				result = yield
				resolve(result)
				return result
			rescue => error
				reject(error)
				raise  # Re-raise so caller knows it failed
			end
		end
		
		# Alias for resolve to match common promise APIs.
		alias signal resolve
	end
end
