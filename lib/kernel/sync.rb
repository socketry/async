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

# Extensions to all Ruby objects.
module Kernel
	# Run the given block of code synchronously, but within a reactor if not already in one.
	#
	# @yields {|task| ...} The block that will execute asynchronously.
	# 	@parameter task [Async::Task] The task that is executing the given block.
	#
	# @public Since `stable-v1`.
	# @asynchronous Will block until given block completes executing.
	def Sync(&block)
		if task = ::Async::Task.current?
			yield task
		else
			reactor = Async::Reactor.new
			
			begin
				return reactor.run(finished: ::Async::Condition.new, &block).wait
			ensure
				Fiber.set_scheduler(nil)
			end
		end
	end
end
