# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2026, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2026, by Robert Mosolgo.

require "fiber"
require_relative "error"
require_relative "list"

module Async
	# A synchronization primitive, which allows fibers to wait until a particular condition is (edge) triggered.
	# @public Since *Async v1*.
	class Condition
		Entry = Struct.new(:value)
		private_constant :Entry
		
		# Create a new condition.
		def initialize
			@ready = ::Thread::Queue.new
		end
		
		# Queue up the current fiber and wait until the condition is signalled.
		# @parameter timeout [Numeric | Nil] The maximum time to wait, or `nil` to wait indefinitely.
		# @returns [Object]
		# @raises [Async::TimeoutError] If the timeout expires before the condition is signalled.
		def wait(timeout: nil)
			if entry = @ready.pop(timeout: timeout)
				return entry.value
			else
				raise TimeoutError, "Timeout while waiting for condition!"
			end
		end
		
		# @returns [Boolean] If there are no fibers waiting on this condition.
		def empty?
			@ready.num_waiting.zero?
		end
		
		# @returns [Boolean] Is any fiber waiting on this notification?
		def waiting?
			!self.empty?
		end
		
		# @returns [Integer] Number of fibers waiting on this condition.
		def waiting_count
			@ready.num_waiting
		end
		
		# Signal to a given task that it should resume operations.
		# @parameter value [Object | Nil] The value to return to the waiting fibers.
		def signal(value = nil)
			return if empty?
			
			ready = self.exchange
			entry = Entry.new(value)
			
			ready.num_waiting.times do
				ready.push(entry)
			end
			
			ready.close
			
			return nil
		end
		
		protected
		
		def exchange
			ready = @ready
			@ready = ::Thread::Queue.new
			return ready
		end
	end
end
