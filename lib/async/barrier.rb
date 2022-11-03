# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative 'list'
require_relative 'task'

module Async
	# A synchronization primitive, which allows one task to wait for a number of other tasks to complete. It can be used in conjunction with {Semaphore}.
	# @public Since `stable-v1`.
	class Barrier
		# Initialize the barrier.
		# @parameter parent [Task | Semaphore | Nil] The parent for holding any children tasks.
		# @public Since `stable-v1`.
		def initialize(parent: nil)
			@tasks = List.new
			
			@parent = parent
		end
		
		class Waiting < List::Node
			def initialize(task)
				@task = task
			end
			
			attr :task
		end
		
		# Number of tasks being held by the barrier.
		def size
			@tasks.size
		end
		
		# All tasks which have been invoked into the barrier.
		attr :tasks
		
		# Execute a child task and add it to the barrier.
		# @asynchronous Executes the given block concurrently.
		def async(*arguments, parent: (@parent or Task.current), **options, &block)
			task = parent.async(*arguments, **options, &block)
			
			@tasks.append(Waiting.new(task))
			
			return task
		end
		
		# Whether there are any tasks being held by the barrier.
		# @returns [Boolean]
		def empty?
			@tasks.empty?
		end
		
		# Wait for all tasks to complete by invoking {Task#wait} on each waiting task, which may raise an error. As long as the task has completed, it will be removed from the barrier.
		# @asynchronous Will wait for tasks to finish executing.
		def wait
			@tasks.each do |waiting|
				task = waiting.task
				begin
					task.wait
				ensure
					@tasks.remove?(waiting) unless task.alive?
				end
			end
		end
		
		# Wait for all tasks co complete by invoking {Task#join} on each waiting task, which does not raise any errors. Tasks will be remoevd from the barrier after joining.
		def join
			@tasks.each do |waiting|
				task = waiting.task
				task.join
				@tasks.remove?(waiting)
			end
		end
		
		# Stop all tasks held by the barrier.
		# @asynchronous May wait for tasks to finish executing.
		def stop
			@tasks.each do |waiting|
				waiting.task.stop
			end
		end
	end
end
