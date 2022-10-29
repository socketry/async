# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.

require 'fiber'
require_relative 'node'

module Async
	# A synchronization primitive, which allows fibers to wait until a particular condition is (edge) triggered.
	# @public Since `stable-v1`.
	class Condition
		def initialize
			@waiting = List.new
		end
		
		# Queue up the current fiber and wait on yielding the task.
		# @returns [Object]
		def wait
			queue = Queue.new(Fiber.current)
			@waiting.insert(queue)
			
			Fiber.scheduler.transfer
		ensure
			queue.delete!
		end
		
		# Is any fiber waiting on this notification?
		# @returns [Boolean]
		def empty?
			@waiting.empty?
		end
		
		# Signal to a given task that it should resume operations.
		# @parameter value [Object | Nil] The value to return to the waiting fibers.
		def signal(value = nil)
			return if @waiting.empty?
			
			waiting = self.exchange
			
			waiting.each do |fiber|
				Fiber.scheduler.resume(fiber, value) if fiber.alive?
			end
			
			return nil
		end
		
		protected
		
		def exchange
			waiting = @waiting
			@waiting = List.new
			return waiting
		end
	end
end
