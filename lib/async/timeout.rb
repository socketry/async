# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	# Represents a flexible timeout that can be rescheduled or extended.
	# @public Since *Async v2.24*.
	class Timeout
		# Initialize a new timeout.
		def initialize(timers, handle, duration = nil)
			@timers = timers
			@handle = handle
			@duration = duration || (handle.time - timers.now)
		end
		
		# @attribute [Numeric] The duration of the timeout.
		attr :duration
		
		# Update the duration of the timeout, rescheduling it if necessary.
		#
		# The duration is relative to the time the timeout was created.
		#
		# @parameter value [Numeric] The new duration to assign to the timeout.
		def duration=(value)
			delta = value - @duration
			self.reschedule(time + delta, value)
		end
		
		# Adjust the timeout by the specified duration, rescheduling it if necessary.
		#
		# @parameter duration [Numeric] The duration to adjust the timeout by.
		# @returns [Numeric] The new time at which the timeout will occur.
		def adjust(duration)
			self.reschedule(time + duration, @duration + duration)
		end
		
		# @returns [Numeric] The time at which the timeout will occur.
		def time
			@handle.time
		end
		
		# Assign a new time to the timeout, rescheduling it if necessary.
		#
		# @parameter value [Numeric] The new time to assign to the timeout.
		# @returns [Numeric] The new time at which the timeout will occur.
		def time=(value)
			self.reschedule(value)
		end
		
		# Cancel the timeout.
		def cancel!
			@handle.cancel!
		end
		
		# @returns [Boolean] Whether the timeout has been cancelled.
		def cancelled?
			@handle.cancelled?
		end
		
		class CancelledError < RuntimeError
		end
		
		# Reschedule the timeout to occur at the specified time.
		#
		# @parameter time [Numeric] The new time to schedule the timeout for.
		# @parameter duration [Numeric | Nil] The new duration to assign to the timeout.
		# @returns [Numeric] The new time at which the timeout will occur.
		private def reschedule(time, duration = nil)
			if block = @handle&.block
				@handle.cancel!
				
				@duration = duration || (time - @timers.now)
				@handle = @timers.schedule(time, block)
				
				return time
			else
				raise CancelledError, "Cannot reschedule a cancelled timeout!"
			end
		end
	end
end
