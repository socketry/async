# frozen_string_literal: true

# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

module Async
	# A synchronization primative, which limits access to a given resource.
	# @public
	class Semaphore
		# @parameter limit [Integer] The maximum number of times the semaphore can be acquired before it blocks.
		# @parameter parent [Task | Semaphore | Nil] The parent for holding any children tasks.
		def initialize(limit = 1, parent: nil)
			@count = 0
			@limit = limit
			@waiting = []
			
			@parent = parent
		end
		
		# The current number of tasks that have acquired the semaphore.
		attr :count
		
		# The maximum number of tasks that can acquire the semaphore.
		attr :limit
		
		# The tasks waiting on this semaphore.
		attr :waiting
		
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
		# @yield when the semaphore can be acquired
		# @return the result of the block if invoked
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
			
			while (@limit - @count) > 0 and fiber = @waiting.shift
				if fiber.alive?
					Fiber.scheduler.resume(fiber)
				end
			end
		end
		
		private
		
		# Wait until the semaphore becomes available.
		def wait
			fiber = Fiber.current
			
			if blocking?
				@waiting << fiber
				Fiber.scheduler.transfer while blocking?
			end
		rescue Exception
			@waiting.delete(fiber)
			raise
		end
	end
end
