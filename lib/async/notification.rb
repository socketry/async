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

require_relative 'condition'

module Async
	# A synchronization primitive, which allows fibers to wait until a notification is received. Does not block the task which signals the notification. Waiting tasks are resumed on next iteration of the reactor.
	class Notification < Condition
		# Signal to a given task that it should resume operations.
		# @return [void]
		def signal(value = nil, task: Task.current)
			return if @waiting.empty?
			
			task.reactor << Signal.new(@waiting, value)
			
			@waiting = []
			
			return nil
		end
		
		Signal = Struct.new(:waiting, :value) do
			def alive?
				true
			end
			
			def resume
				waiting.each do |fiber|
					fiber.resume(value) if fiber.alive?
				end
			end
		end
	end
end
