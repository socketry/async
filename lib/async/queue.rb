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

require_relative 'notification'

module Async
	# A queue which allows items to be processed in order.
	class Queue < Notification
		def initialize(parent: nil)
			super()
			
			@items = []
			@parent = parent
		end
		
		attr :items
		
		def size
			@items.size
		end

		def empty?
			@items.empty?
		end
		
		def <<(item)
			@items << item
			
			self.signal unless self.empty?
		end
		
		def enqueue(*items)
			@items.concat(items)
			
			self.signal unless self.empty?
		end
		
		def dequeue
			while @items.empty?
				self.wait
			end
			
			@items.shift
		end
		
		def async(parent: (@parent or Task.current), &block)
			while item = self.dequeue
				parent.async(item, &block)
			end
		end
		
		def each
			while item = self.dequeue
				yield item
			end
		end
	end
	
	class LimitedQueue < Queue
		def initialize(limit = 1, **options)
			super(**options)
			
			@limit = limit
			
			@full = Notification.new
		end
		
		attr :limit
		
		# @return [Boolean] Whether trying to enqueue an item would block.
		def limited?
			@items.size >= @limit
		end
		
		def <<(item)
			while limited?
				@full.wait
			end
			
			super
		end
		
		def enqueue *items
			while !items.empty?
				while limited?
					@full.wait
				end
				
				available = @limit - @items.size
				@items.concat(items.shift(available))
				
				self.signal unless self.empty?
			end
		end
		
		def dequeue
			item = super
			
			@full.signal
			
			return item
		end
	end
end
