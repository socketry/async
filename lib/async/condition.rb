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

require 'fiber'
require_relative 'node'

module Async
	# A synchronization primative, which allows fibers to wait until a particular condition is triggered. Signalling the condition directly resumes the waiting fibers and thus blocks the caller.
	class Condition
		def initialize
			@waiting = []
		end
		
		# Queue up the current fiber and wait on yielding the task.
		# @return [Object]
		def wait
			fiber = Fiber.current
			@waiting << fiber
			
			Task.yield
			
			# It would be nice if there was a better construct for this. We only need to invoke #delete if the task was not resumed normally. This can only occur with `raise` and `throw`. But there is no easy way to detect this.
		# ensure when not return or ensure when raise, throw
		rescue Exception
			@waiting.delete(fiber)
			raise
		end
		
		# Is any fiber waiting on this notification?
		# @return [Boolean]
		def empty?
			@waiting.empty?
		end
		
		# Signal to a given task that it should resume operations.
		# @param value The value to return to the waiting fibers.
		# @see Task.yield which is responsible for handling value.
		# @return [void]
		def signal(value = nil)
			waiting = @waiting
			@waiting = []
			
			waiting.each do |fiber|
				fiber.resume(value) if fiber.alive?
			end
			
			return nil
		end
	end
end
