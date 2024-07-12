# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.
# Copyright, 2019, by Ryan Musgrave.
# Copyright, 2020-2022, by Bruno Sutic.

require_relative 'notification'

module Async
	# A queue which allows items to be processed in order.
	#
	# It has a compatible interface with {Notification} and {Condition}, except that it's multi-value.
	#
	# @public Since `stable-v1`.
	class Queue
		# Create a new queue.
		#
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		# @parameter available [Notification] The notification to use for signaling when items are available.
		def initialize(parent: nil, available: Notification.new)
			@items = []
			@parent = parent
			@available = available
		end
		
		# @attribute [Array] The items in the queue.
		attr :items
		
		# @returns [Integer] The number of items in the queue.
		def size
			@items.size
		end
		
		# @returns [Boolean] Whether the queue is empty.
		def empty?
			@items.empty?
		end
		
		# Add an item to the queue.
		def <<(item)
			@items << item
			
			@available.signal unless self.empty?
		end
		
		# Add multiple items to the queue.
		def enqueue(*items)
			@items.concat(items)
			
			@available.signal unless self.empty?
		end
		
		# Remove and return the next item from the queue.
		def dequeue
			while @items.empty?
				@available.wait
			end
			
			@items.shift
		end
		
		# Process each item in the queue.
		#
		# @asynchronous Executes the given block concurrently for each item.
		#
		# @parameter arguments [Array] The arguments to pass to the block.
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		# @parameter options [Hash] The options to pass to the task.
		# @yields {|task| ...} When the system is idle, the block will be executed in a new task.
		def async(parent: (@parent or Task.current), **options, &block)
			while item = self.dequeue
				parent.async(item, **options, &block)
			end
		end
		
		# Enumerate each item in the queue.
		def each
			while item = self.dequeue
				yield item
			end
		end
		
		# Signal the queue with a value, the same as {#enqueue}.
		def signal(value)
			self.enqueue(value)
		end
		
		# Wait for an item to be available, the same as {#dequeue}.
		def wait
			self.dequeue
		end
	end
	
	# A queue which limits the number of items that can be enqueued.
	# @public Since `stable-v1`.
	class LimitedQueue < Queue
		# Create a new limited queue.
		#
		# @parameter limit [Integer] The maximum number of items that can be enqueued.
		# @parameter full [Notification] The notification to use for signaling when the queue is full.
		def initialize(limit = 1, full: Notification.new, **options)
			super(**options)
			
			@limit = limit
			@full = full
		end
		
		# @attribute [Integer] The maximum number of items that can be enqueued.
		attr :limit
		
		# @returns [Boolean] Whether trying to enqueue an item would block.
		def limited?
			@items.size >= @limit
		end
		
		# Add an item to the queue.
		#
		# If the queue is full, this method will block until there is space available.
		#
		# @parameter item [Object] The item to add to the queue.
		def <<(item)
			while limited?
				@full.wait
			end
			
			super
		end
		
		# Add multiple items to the queue.
		#
		# If the queue is full, this method will block until there is space available. 
		#
		# @parameter items [Array] The items to add to the queue.
		def enqueue(*items)
			while !items.empty?
				while limited?
					@full.wait
				end
				
				available = @limit - @items.size
				@items.concat(items.shift(available))
				
				@available.signal unless self.empty?
			end
		end
		
		# Remove and return the next item from the queue.
		#
		# If the queue is empty, this method will block until an item is available.
		#
		# @returns [Object] The next item in the queue.
		def dequeue
			item = super
			
			@full.signal
			
			return item
		end
	end
end
