# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2026, by Samuel Williams.
# Copyright, 2026, by Tavian Barnes.

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
			@condition = Condition.new
			
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
		# @returns [Task] The task which was created to execute the block.
		def async(*arguments, parent: (@parent or Task.current), **options, &block)
			raise "Barrier is stopped!" if @finished.closed?
			
			waiting = nil
			
			task = parent.async(*arguments, **options) do |task, *arguments|
				# Create a new list node for the task and add it to the list of waiting tasks:
				node = TaskNode.new(task)
				@tasks.append(node)
				
				# Signal the outer async block that we have added the task to the list of waiting tasks, and that it can now wait for it to finish:
				waiting = node
				@condition.signal
				
				# Invoke the block, which may raise an error. If it does, we will still signal that the task has finished:
				block.call(task, *arguments)
			ensure
				# Signal that the task has finished, which will unblock the waiting task:
				@finished.signal(node) unless @finished.closed?
			end
			
			# `parent.async` may yield before the child block executes, so we wait here until the child has appended itself to `@tasks`, ensuring `wait` cannot return early and miss tracking it:
			@condition.wait while waiting.nil?
			
			return task
		end
		
		# Whether there are any tasks being held by the barrier.
		# @returns [Boolean]
		def empty?
			@tasks.empty?
		end
		
		# Wait for all tasks to complete by invoking {Task#wait} on each waiting task, which may raise an error. As long as the task has completed, it will be removed from the barrier.
		#
		# @yields {|task| ...} If a block is given, the unwaited task is yielded. You must invoke {Task#wait} yourself. In addition, you may `break` if you have captured enough results.
		# @returns [Integer | Nil] The number of tasks which were waited for, or `nil` if there were no tasks to wait for.
		#
		# @asynchronous Will wait for tasks to finish executing.
		def wait
			return nil if @tasks.empty?
			count = 0
			
			while true
				# Wait for a task to finish (we get the task node):
				break unless waiting = @finished.wait
				count += 1
				
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
				
				break if @tasks.empty?
			end
			
			return count
		end
		
		# Cancel all tasks held by the barrier.
		# @asynchronous May wait for tasks to finish executing.
		def cancel
			@tasks.each do |waiting|
				waiting.task.cancel
			end
			
			@finished.close
		end
		
		# Backward compatibility alias for {#cancel}.
		# @deprecated Use {#cancel} instead.
		def stop
			cancel
		end
	end
end
