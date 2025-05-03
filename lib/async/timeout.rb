# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	# Represents a flexible timeout that can be rescheduled or extended.
	# @public Since *Async v2.24*.
	class Timeout
		# Initialize a new timeout.
		def initialize(timers, handle)
			@timers = timers
			@handle = handle
		end
		
		# @returns [Numeric] The time remaining until the timeout occurs, in seconds.
		def duration
			@handle.time - @timers.now
		end
		
		# Update the duration of the timeout.
		#
		# The duration is relative to the current time, e.g. setting the duration to 5 means the timeout will occur in 5 seconds from now.
		#
		# @parameter value [Numeric] The new duration to assign to the timeout, in seconds.
		def duration=(value)
			self.reschedule(@timers.now + value)
		end
		
		# Adjust the timeout by the specified duration.
		#
		# The duration is relative to the timeout time, e.g. adjusting the timeout by 5 increases the current duration by 5 seconds.
		#
		# @parameter duration [Numeric] The duration to adjust the timeout by, in seconds.
		# @returns [Numeric] The new time at which the timeout will occur.
		def adjust(duration)
			self.reschedule(time + duration)
		end
		
		# @returns [Numeric] The time at which the timeout will occur, in seconds since {now}.
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
		
		# @returns [Numeric] The current time in the scheduler, relative to the time of this timeout, in seconds.
		def now
			@timers.now
		end
		
		# Cancel the timeout, preventing it from executing.
		def cancel!
			@handle.cancel!
		end
		
		# @returns [Boolean] Whether the timeout has been cancelled.
		def cancelled?
			@handle.cancelled?
		end
		
		# Raised when attempting to reschedule a cancelled timeout.
		class CancelledError < RuntimeError
		end
		
		# Reschedule the timeout to occur at the specified time.
		#
		# @parameter time [Numeric] The new time to schedule the timeout for.
		# @returns [Numeric] The new time at which the timeout will occur.
		private def reschedule(time)
			if block = @handle&.block
				@handle.cancel!
				
				@handle = @timers.schedule(time, block)
				
				return time
			else
				raise CancelledError, "Cannot reschedule a cancelled timeout!"
			end
		end
	end
end
