# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'scheduler'
require_relative 'task'

module Async
	class Reactor < Scheduler
		# The preferred method to invoke asynchronous behavior at the top level.
		#
		# - When invoked within an existing reactor task, it will run the given block
		# asynchronously. Will return the task once it has been scheduled.
		# - When invoked at the top level, will create and run a reactor, and invoke
		# the block as an asynchronous task. Will block until the reactor finishes
		# running.
		def self.run(*arguments, **options, &block)
			if current = Task.current?
				return current.async(*arguments, **options, &block)
			else
				reactor = self.new
				
				begin
					return reactor.run(*arguments, **options, &block)
				ensure
					reactor.close
				end
			end
		end
		
		def initialize(...)
			super
			
			@closing = false
			self.set!
		end
		
		def to_s
			"\#<#{self.description} #{@children&.size || 0} children (#{stopped? ? 'stopped' : 'running'})>"
		end
		
		# Start an asynchronous task within the specified reactor. The task will be
		# executed until the first blocking call, at which point it will yield and
		# and this method will return.
		#
		# This is the main entry point for scheduling asynchronus tasks.
		#
		# @yield [Task] Executed within the task.
		# @return [Task] The task that was scheduled into the reactor.
		def async(*arguments, **options, &block)
			task = Task.new(self, **options, &block)
			
			# I want to take a moment to explain the logic of this.
			# When calling an async block, we deterministically execute it until the
			# first blocking operation. We don't *have* to do this - we could schedule
			# it for later execution, but it's useful to:
			# - Fail at the point of the method call where possible.
			# - Execute determinstically where possible.
			# - Avoid scheduler overhead if no blocking operation is performed.
			task.run(*arguments)
			
			# Console.logger.debug "Initial execution of task #{fiber} complete (#{result} -> #{fiber.alive?})..."
			return task
		end
		
		def close
			if @closing
				super
			else
				@closing = true
				self.clear!
			end
		end
		
		public :sleep
		
		def with_timeout(timeout, exception = TimeoutError, message = "execution expired", &block)
			timeout_after(timeout, exception, message, &block)
		end
	end
end
