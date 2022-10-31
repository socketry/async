# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

module Async
	# A composable synchronization primitive, which allows one task to wait for a number of other tasks to complete. It can be used in conjunction with {Semaphore} and/or {Barrier}.
	class LimitedBarrier
		def initialize(parent: nil, finished: Async::Condition.new)
			@finished = finished
			@done = []
			
			@parent = parent
		end
		
		def async(parent: (@parent or Task.current), &block)
			parent.async do |task|
				yield(task)
			ensure
				@done << task
				@finished.signal
			end
		end
		
		def wait_for(count)
			while @done.size < count
				@finished.wait
			end
			
			return @done.shift(count)
		end
		
		def wait(count)
			wait_for(count).map(&:result)
		end
	end
end
