# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "queue"

module Async
	# A queue which limits the number of items that can be enqueued.
	# @public Since *Async v1*.
	class LimitedQueue < Queue
		def self.new(...)
			super
		end
		
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
		
		# Close the queue, causing all waiting tasks to return `nil`. Any subsequent calls to {enqueue} will raise an exception.
		# Also signals all tasks waiting for the queue to be full.
		def close
			super
			
			while @full.waiting?
				@full.signal(nil)
			end
		end
		
		# @returns [Boolean] Whether trying to enqueue an item would block.
		def limited?
			!@closed && @items.size >= @limit
		end
		
		# Add an item to the queue.
		#
		# If the queue is full, this method will block until there is space available.
		#
		# @parameter item [Object] The item to add to the queue.
		def push(item)
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
				
				if @closed
					raise ClosedError, "Cannot enqueue items to a closed queue."
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