# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require_relative "condition"

module Async
	# A synchronization primitive, which allows fibers to wait until a notification is received. Does not block the task which signals the notification. Waiting tasks are resumed on next iteration of the reactor.
	# @public Since *Async v1*.
	class Notification < Condition
		# Signal to a given task that it should resume operations.
		#
		# @returns [Boolean] if a task was signalled.
		def signal(value = nil)
			return false if empty?
			
			Fiber.scheduler.push Signal.new(self.exchange, value)
			
			return true
		end
		
		Signal = Struct.new(:ready, :value) do
			def alive?
				true
			end
			
			def transfer
				ready.num_waiting.times do
					ready.push(value)
				end
				
				ready.close
			end
		end
		
		private_constant :Signal
	end
end
