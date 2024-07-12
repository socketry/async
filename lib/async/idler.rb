# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

module Async
	# A load balancing mechanism that can be used process work when the system is idle.
	class Idler
		# Create a new idler.
		# @public Since `stable-v2`.
		#
		# @parameter maximum_load [Numeric] The maximum load before we start shedding work.
		# @parameter backoff [Numeric] The initial backoff time, used for delaying work.
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		def initialize(maximum_load = 0.8, backoff: 0.01, parent: nil)
			@maximum_load = maximum_load
			@backoff = backoff
			@parent = parent
		end
		
		# Wait until the system is idle, then execute the given block in a new task.
		#
		# @asynchronous Executes the given block concurrently.
		#
		# @parameter arguments [Array] The arguments to pass to the block.
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		# @parameter options [Hash] The options to pass to the task.
		# @yields {|task| ...} When the system is idle, the block will be executed in a new task.
		def async(*arguments, parent: (@parent or Task.current), **options, &block)
			wait
			
			# It is crucial that we optimistically execute the child task, so that we prevent a tight loop invoking this method from consuming all available resources.
			parent.async(*arguments, **options, &block)
		end
		
		# Wait until the system is idle, according to the maximum load specified.
		#
		# If the scheduler is overloaded, this method will sleep for an exponentially increasing amount of time.
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
