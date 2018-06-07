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
	# A semaphore is used to control access to a common resource in a concurrent system. A useful way to think of a semaphore as used in the real-world systems is as a record of how many units of a particular resource are available, coupled with operations to adjust that record safely (i.e. to avoid race conditions) as units are required or become free, and, if necessary, wait until a unit of the resource becomes available.
	class Semaphore
		def initialize(limit = 1)
			@count = 0
			@limit = limit
			@waiting = []
		end
		
		attr :count
		attr :limit
		
		# Whether trying to acquire this semaphore would block.
		def blocking?
			@count >= @limit
		end
		
		# Acquire the semaphore, block if we are at the limit.
		# If no block is provided, you must call release manually.
		# @yield when the semaphore can be acquired
		# @return the result of the block if invoked
		def acquire
			while blocking?
				@waiting << Fiber.current
				Task.yield
			end
			
			@count += 1
			
			return unless block_given?
			
			begin
				return yield
			ensure
				self.release
			end
		end
		
		# Release the semaphore. Must match up with a corresponding call to `acquire`.
		def release(task: Task.current)
			@count -= 1
			
			task.reactor << self if @waiting.any?
		end
		
		# Whether this semaphore has work to do when being resumed.
		def alive?
			@waiting.any?
		end
		
		# Resume tasks waiting on the semaphore, up to the maximum to the available limit.
		def resume
			available = @waiting.pop(@limit - @count)
			
			available.each(&:resume)
		end
	end
end
