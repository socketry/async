# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

module Async
	# A composable synchronization primitive, which allows one task to wait for a number of other tasks to complete. It can be used in conjunction with {Semaphore} and/or {Barrier}.
	class Waiter
		def initialize(parent: nil, finished: Async::Condition.new)
			@finished = finished
			@done = []
			
			@parent = parent
		end
		
		# Execute a child task and add it to the waiter.
		# @asynchronous Executes the given block concurrently.
		def async(parent: (@parent or Task.current), &block)
			parent.async do |task|
				yield(task)
			ensure
				@done << task
				@finished.signal
			end
		end
		
		# Wait for the first `count` tasks to complete.
		# @parameter count [Integer | Nil] The number of tasks to wait for.
		# @returns [Array(Async::Task)] If an integer is given, the tasks which have completed.
		# @returns [Async::Task] Otherwise, the first task to complete.
		def first(count = nil)
			minimum = count || 1
			
			while @done.size < minimum
				@finished.wait
			end
			
			return @done.shift(*count)
		end
		
		# Wait for the first `count` tasks to complete.
		# @parameter count [Integer | Nil] The number of tasks to wait for.
		def wait(count = nil)
			if count
				first(count).map(&:wait)
			else
				first.wait
			end
		end
	end
end
