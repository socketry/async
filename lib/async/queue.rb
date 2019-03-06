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

require_relative 'notification'

module Async
	# A queue which allows items to be processed in order.
	class Queue < Notification
		def initialize
			super
			
			@items = []
		end
		
		attr :items
		
		def enqueue item
			@items.push(item)
			
			self.signal unless self.empty?
		end
		
		def dequeue
			while @items.empty?
				self.wait
			end
			
			@items.shift
		end
	end
	
	class LimitedQueue < Queue
		def initialize(limit = 1)
			super()
			
			@limit = limit
			@full = Async::Queue.new
		end
		
		attr :limit
		
		# @return [Boolean] Whether trying to enqueue an item would block.
		def limited?
			@items.size >= @limit
		end
		
		def enqueue item
			if limited?
				@full.dequeue
			end
			
			super
		end
		
		def dequeue
			item = super
			
			@full.enqueue(nil) unless @full.empty?
			
			return item
		end
	end
end
