# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require_relative "list"
require_relative "task"
require_relative "queue"

module Async
	# A general purpose synchronisation primitive, which allows one task to wait for a number of other tasks to complete. It can be used in conjunction with {Semaphore}.
	#
	# @public Since *Async v1*.
	class Barrier
		# Initialize the barrier.
		# @parameter parent [Task | Semaphore | Nil] The parent for holding any children tasks.
		# @public Since *Async v1*.
		def initialize(parent: nil)
			@tasks = List.new
			@finished = Queue.new
			
			@parent = parent
		end
		
		class TaskNode < List::Node
			def initialize(task)
				@task = task
			end
			
			attr :task
		end
		
		private_constant :TaskNode
		
		# Number of tasks being held by the barrier.
		def size
			@tasks.size
		end
		
		# All tasks which have been invoked into the barrier.
		attr :tasks
		
		# Execute a child task and add it to the barrier.
		# @asynchronous Executes the given block concurrently.
		def async(*arguments, parent: (@parent or Task.current), **options, &block)
			waiting = nil
			
			parent.async(*arguments, **options) do |task, *arguments|
				waiting = TaskNode.new(task)
				@tasks.append(waiting)
				block.call(task, *arguments)
			ensure
				@finished.signal(waiting)
			end
		end
		
		# Whether there are any tasks being held by the barrier.
		# @returns [Boolean]
		def empty?
			@tasks.empty?
		end
		
		# Wait for all tasks to complete by invoking {Task#wait} on each waiting task, which may raise an error. As long as the task has completed, it will be removed from the barrier.
		#
		# @yields {|task| ...} If a block is given, the unwaited task is yielded. You must invoke {Task#wait} yourself. In addition, you may `break` if you have captured enough results.
		#
		# @asynchronous Will wait for tasks to finish executing.
		def wait
			while !@tasks.empty?
				# Wait for a task to finish (we get the task node):
				return unless waiting = @finished.wait
				
				# Remove the task as it is now finishing:
				@tasks.remove?(waiting)
				
				# Get the task:
				task = waiting.task
				
				# If a block is given, the user can implement their own behaviour:
				if block_given?
					yield task
				else
					# Wait for it to either complete or raise an error:
					task.wait
				end
			end
		end
		
		# Stop all tasks held by the barrier.
		# @asynchronous May wait for tasks to finish executing.
		def stop
			@tasks.each do |waiting|
				waiting.task.stop
			end
			
			@finished.close
		end
	end
end
