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

require_relative "../async/reactor"

module Kernel
	# Run the given block of code in a task, asynchronously, creating a reactor if necessary.
	#
	# The preferred method to invoke asynchronous behavior at the top level.
	#
	# - When invoked within an existing reactor task, it will run the given block
	# asynchronously. Will return the task once it has been scheduled.
	# - When invoked at the top level, will create and run a reactor, and invoke
	# the block as an asynchronous task. Will block until the reactor finishes
	# running.
	#
	# @yields {|task| ...} The block that will execute asynchronously.
	# 	@parameter task [Async::Task] The task that is executing the given block.
	#
	# @public Since `stable-v1`.
	# @asynchronous May block until given block completes executing.
	def Async(...)
		if current = ::Async::Task.current?
			return current.async(...)
		else
			reactor = ::Async::Reactor.new
			
			begin
				return reactor.run(...)
			ensure
				Fiber.set_scheduler(nil)
			end
		end
	end
end
