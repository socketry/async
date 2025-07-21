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
		# @returns [bool] If a task was signalled.
		def signal(value = nil, task: Task.current)
			return false if @waiting.empty?
			
			Fiber.scheduler.push Signal.new(self.exchange, value)
			
			return true
		end
		
		Signal = Struct.new(:waiting, :value) do
			# @returns [bool] Returns true if the signal is still alive.
			def alive?
				true
			end
			
			# Transfer the value to all waiting fibers.
			# @returns [self]
			def transfer
				waiting.each do |fiber|
					fiber.transfer(value) if fiber.alive?
				end
				
				return self
			end
		end
		
		private_constant :Signal
	end
end
