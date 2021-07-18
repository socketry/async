# frozen_string_literal: true

# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'task'

module Async
	# A barrier is used to synchronize multiple tasks, waiting for them all to complete before continuing.
	# @public
	class Barrier
		# Initialize the barrier.
		# @parameter parent [Task | Semaphore | Nil] The parent for holding any children tasks.
		# @public
		def initialize(parent: nil)
			@tasks = []
			
			@parent = parent
		end
		
		# All tasks which have been invoked into the barrier.
		# @public
		attr :tasks
		
		# The number of tasks currently held by the barrier.
		# @public
		def size
			@tasks.size
		end
		
		# Execute a child task and add it to the barrier.
		# @asynchronous execution of the given block.
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
		
		# Wait for tasks in FIFO order.
		# @asynchronous if there are held tasks.
		def wait
			while task = @tasks.shift
				task.wait
			end
		end
		
		# Stop all tasks held by the barrier.
		# @asynchronous if there are held tasks.
		def stop
			while task = @tasks.shift
				task.stop
			end
		end
	end
end
