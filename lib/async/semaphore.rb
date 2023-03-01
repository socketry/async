# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require_relative 'list'

module Async
	# A synchronization primitive, which limits access to a given resource.
	# @public Since `stable-v1`.
	class Semaphore
		# @parameter limit [Integer] The maximum number of times the semaphore can be acquired before it blocks.
		# @parameter parent [Task | Semaphore | Nil] The parent for holding any children tasks.
		def initialize(limit = 1, parent: nil)
			@count = 0
			@limit = limit
			@waiting = List.new
			
			@parent = parent
		end
		
		# The current number of tasks that have acquired the semaphore.
		attr :count
		
		# The maximum number of tasks that can acquire the semaphore.
		attr :limit
		
		# The tasks waiting on this semaphore.
		attr :waiting
		
		# Allow setting the limit. This is useful for cases where the semaphore is used to limit the number of concurrent tasks, but the number of tasks is not known in advance or needs to be modified.
		#
		# On increasing the limit, some tasks may be immediately resumed. On decreasing the limit, some tasks may execute until the count is < than the limit. 
		#
		# @parameter limit [Integer] The new limit.
		def limit= limit
			difference = limit - @limit
			@limit = limit
			
			# We can't suspend 
			if difference > 0
				difference.times do
					break unless node = @waiting.first
					
					node.resume
				end
			end
		end
		
		# Is the semaphore currently acquired?
		def empty?
			@count.zero?
		end
		
		# Whether trying to acquire this semaphore would block.
		def blocking?
			@count >= @limit
		end
		
		# Run an async task. Will wait until the semaphore is ready until spawning and running the task.
		def async(*arguments, parent: (@parent or Task.current), **options)
			wait
			
			parent.async(**options) do |task|
				@count += 1
				
				begin
					yield task, *arguments
				ensure
					self.release
				end
			end
		end
		
		# Acquire the semaphore, block if we are at the limit.
		# If no block is provided, you must call release manually.
		# @yields {...} When the semaphore can be acquired.
		# @returns The result of the block if invoked.
		def acquire
			wait
			
			@count += 1
			
			return unless block_given?
			
			begin
				return yield
			ensure
				self.release
			end
		end
		
		# Release the semaphore. Must match up with a corresponding call to `acquire`. Will release waiting fibers in FIFO order.
		def release
			@count -= 1
			
			while (@limit - @count) > 0 and node = @waiting.first
				node.resume
			end
		end
		
		private
		
		class FiberNode < List::Node
			def initialize(fiber)
				@fiber = fiber
			end
			
			def resume
				if @fiber.alive?
					Fiber.scheduler.resume(@fiber)
				end
			end
		end
		
		private_constant :FiberNode
		
		# Wait until the semaphore becomes available.
		def wait
			return unless blocking?
			
			@waiting.stack(FiberNode.new(Fiber.current)) do
				Fiber.scheduler.transfer while blocking?
			end
		end
	end
end
