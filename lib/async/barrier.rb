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
	class Barrier
		def initialize(parent: nil)
			@tasks = []
			
			@parent = parent
		end
		
		# All tasks which have been invoked into the barrier.
		attr :tasks
		
		def size
			@tasks.size
		end
		
		def async(*arguments, parent: (@parent or Task.current), **options, &block)
			task = parent.async(*arguments, **options, &block)
			
			@tasks << task
			
			return task
		end
		
		def empty?
			@tasks.empty?
		end
		
		# Wait for tasks in FIFO order.
		def wait
			while task = @tasks.shift
				task.wait
			end
		end
		
		def stop
			while task = @tasks.shift
				task.stop
			end
		end
	end
end
