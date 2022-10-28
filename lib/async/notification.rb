# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.

require_relative 'condition'

module Async
	# A synchronization primitive, which allows fibers to wait until a notification is received. Does not block the task which signals the notification. Waiting tasks are resumed on next iteration of the reactor.
	# @public Since `stable-v1`.
	class Notification < Condition
		# Signal to a given task that it should resume operations.
		def signal(value = nil, task: Task.current)
			return if @waiting.empty?
			
			Fiber.scheduler.push Signal.new(self.exchange, value)
			
			return nil
		end
		
		Signal = Struct.new(:waiting, :value) do
			def alive?
				true
			end
			
			def transfer
				waiting.each do |fiber|
					fiber.transfer(value) if fiber.alive?
				end
			end
		end
	end
end
