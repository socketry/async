# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.

require "fiber"
require_relative "list"

module Async
	# A synchronization primitive, which allows fibers to wait until a particular condition is (edge) triggered.
	# @public Since *Async v1*.
	class Condition
		# Create a new condition.
		def initialize
			@ready = ::Thread::Queue.new
		end
		
		# Queue up the current fiber and wait on yielding the task.
		# @returns [Object]
		def wait
			@ready.pop
		end
		
		# @returns [Boolean] If there are no fibers waiting on this condition.
		def empty?
			@ready.num_waiting.zero?
		end
		
		# @returns [Boolean] Is any fiber waiting on this notification?
		def waiting?
			!self.empty?
		end
		
		# Signal to a given task that it should resume operations.
		# @parameter value [Object | Nil] The value to return to the waiting fibers.
		def signal(value = nil)
			return if empty?
			
			ready = self.exchange
			
			ready.num_waiting.times do
				ready.push(value)
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
