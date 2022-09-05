# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative 'task'

module Async
	# A synchronization primitive, which allows one task to wait for a number of other tasks to complete. It can be used in conjunction with {Semaphore}.
	# @public Since `stable-v1`.
	class Barrier
		# Initialize the barrier.
		# @parameter parent [Task | Semaphore | Nil] The parent for holding any children tasks.
		# @public Since `stable-v1`.
		def initialize(parent: nil)
			@tasks = []
			
			@parent = parent
		end
		
		# All tasks which have been invoked into the barrier.
		attr :tasks
		
		# The number of tasks currently held by the barrier.
		def size
			@tasks.size
		end
		
		# Execute a child task and add it to the barrier.
		# @asynchronous Executes the given block concurrently.
		def async(*arguments, parent: (@parent or Task.current), **options, &block)
			task = parent.async(*arguments, **options, &block)
			
			@tasks << task
			
			return task
		end
		
		# Whether there are any tasks being held by the barrier.
		# @returns [Boolean]
		def empty?
			@tasks.empty?
		end
		
		# Wait for all tasks.
		# @asynchronous Will wait for tasks to finish executing.
		def wait
			# TODO: This would be better with linked list.
			while @tasks.any?
				task = @tasks.first
				
				begin
					task.wait
				ensure
					# We don't know for sure that the exception was due to the task completion.
					unless task.running?
						# Remove the task from the waiting list if it's finished:
						@tasks.shift if @tasks.first == task
					end
				end
			end
		end
		
		# Stop all tasks held by the barrier.
		# @asynchronous May wait for tasks to finish executing.
		def stop
			# We have to be careful to avoid enumerating tasks while adding/removing to it:
			tasks = @tasks.dup
			tasks.each(&:stop)
		end
	end
end
