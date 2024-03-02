# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

module Async
	class Idler
		def initialize(maximum_load = 0.8, backoff: 0.01, parent: nil)
			@maximum_load = maximum_load
			@backoff = backoff
			@parent = parent
		end
		
		def async(*arguments, parent: (@parent or Task.current), **options, &block)
			wait
			
			# It is crucial that we optimistically execute the child task, so that we prevent a tight loop invoking this method from consuming all available resources.
			parent.async(*arguments, **options, &block)
		end
		
		def wait
			scheduler = Fiber.scheduler
			backoff = nil
			
			while true
				load = scheduler.load 
				break if load < @maximum_load
				
				if backoff
					sleep(backoff)
					backoff *= 2.0
				else
					scheduler.yield
					backoff = @backoff
				end
			end
		end
	end
end
