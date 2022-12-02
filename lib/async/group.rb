# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative 'list'
require_relative 'task'

module Async
	# A group is a collection of child tasks, similar to how a task has a collection of child tasks.
	class Group < Node
		def initialize(parent = Task.current, **options)
			super(parent, **options)
		end
		
		# Execute a child task and add it to the barrier.
		# @asynchronous Executes the given block concurrently.
		def async(*arguments, **options, &block)
			task = Task.new(self, **options, &block)
			
			task.run(*arguments)
			
			return task
		end
		
		# Wait for all children tasks to finish by calling {Task#wait} on each child, which may raise an error.
		def wait
			self.children.each do |child|
				child.wait
			end
		end
	end
end
