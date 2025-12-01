# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

module Async
	# A load balancing mechanism that can be used process work when the system is idle.
	class Idler
		# Create a new idler.
		#
		# @public Since *Async v2*.
		#
		# @parameter maximum_load [Numeric] The maximum load before we start shedding work.
		# @parameter backoff [Numeric] The initial backoff time, used for delaying work.
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		def initialize(maximum_load = 0.8, backoff: 0.001, parent: nil)
			@maximum_load = maximum_load
			@backoff = backoff
			@current = backoff
			
			@parent = parent
			@mutex = Mutex.new
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
			@mutex.synchronize do
				scheduler = Fiber.scheduler
				
				while true
					load = scheduler.load
					
					if load <= @maximum_load
						# Even though load is okay, if @current is high, we were recently overloaded. Sleep proportionally to prevent burst after load drop:
						if @current > @backoff
							# Sleep a fraction of @current to rate limit:
							sleep(@current - @backoff)
							
							# Decay @current gently towards @backoff:
							alpha = 0.99
							@current *= alpha + (1.0 - alpha) * (load / @maximum_load)
						end
						
						break
					else
						# We're overloaded, so increase backoff:
						@current *= (load / @maximum_load)
						sleep(@current)
					end
				end
			end
		end
	end
end
