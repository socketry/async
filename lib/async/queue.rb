# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.
# Copyright, 2019, by Ryan Musgrave.
# Copyright, 2020-2022, by Bruno Sutic.
# Copyright, 2025, by Jahfer Husain.

require_relative "notification"

module Async
	# A queue which allows items to be processed in order.
	#
	# It has a compatible interface with {Notification} and {Condition}, except that it's multi-value.
	#
	# @public Since *Async v1*.
	class Queue
		# An error raised when trying to enqueue items to a closed queue.
		# @public Since *Async v2.24*.
		class ClosedError < RuntimeError
		end
		
		# Create a new queue.
		#
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		# @parameter available [Notification] The notification to use for signaling when items are available.
		def initialize(parent: nil, available: Notification.new)
			@items = []
			@closed = false
			@parent = parent
			@available = available
		end
		
		# Close the queue, causing all waiting tasks to return `nil`. Any subsequent calls to {enqueue} will raise an exception.
		def close
			@closed = true
			
			while @available.waiting?
				@available.signal(nil)
			end
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
		def push(item)
			if @closed
				raise ClosedError, "Cannot push items to a closed queue."
			end
			
			@items << item
			
			@available.signal unless self.empty?
		end
		
		# Compatibility with {::Queue#push}.
		def <<(item)
			self.push(item)
		end
		
		# Add multiple items to the queue.
		def enqueue(*items)
			if @closed
				raise ClosedError, "Cannot enqueue items to a closed queue."
			end
			
			@items.concat(items)
			
			@available.signal unless self.empty?
		end
		
		# Remove and return the next item from the queue.
		def dequeue
			while @items.empty?
				if @closed
					return nil
				end
				
				@available.wait
			end
			
			@items.shift
		end
		
		# Compatibility with {::Queue#pop}.
		def pop
			self.dequeue
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
		def signal(value = nil)
			self.enqueue(value)
		end
		
		# Wait for an item to be available, the same as {#dequeue}.
		def wait
			self.dequeue
		end
	end
	
	# @private
	class LimitedQueue < Queue
		# This gets redefined if you load `async/limited_queue`.
		def self.new(...)
			warn "Use `require 'async/limited_queue'` to use `Async::LimitedQueue` without a warning.", uplevel: 1
			
			require_relative "limited_queue"
			
			super(...)
		end
	end
end
