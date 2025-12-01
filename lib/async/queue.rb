# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.
# Copyright, 2019, by Ryan Musgrave.
# Copyright, 2020-2022, by Bruno Sutic.
# Copyright, 2025, by Jahfer Husain.
# Copyright, 2025, by Shopify Inc.

require_relative "notification"

module Async
	# A thread-safe queue which allows items to be processed in order.
	#
	# This implementation uses Thread::Queue internally for thread safety while
	# maintaining compatibility with the fiber scheduler.
	#
	# It has a compatible interface with {Notification} and {Condition}, except that it's multi-value.
	#
	# @asynchronous This class is thread-safe.
	# @public Since *Async v1*.
	class Queue
		# An error raised when trying to enqueue items to a closed queue.
		# @public Since *Async v2.24*.
		class ClosedError < RuntimeError
		end
		
		# Create a new thread-safe queue.
		#
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		def initialize(parent: nil, delegate: Thread::Queue.new)
			@delegate = delegate
			@parent = parent
		end
		
		# @returns [Boolean] Whether the queue is closed.
		def closed?
			@delegate.closed?
		end
		
		# Close the queue, causing all waiting tasks to return `nil`. Any subsequent calls to {enqueue} will raise an exception.
		def close
			@delegate.close
		end
		
		# @returns [Integer] The number of items in the queue.
		def size
			@delegate.size
		end
		
		# @returns [Boolean] Whether the queue is empty.
		def empty?
			@delegate.empty?
		end
		
		# @returns [Integer] The number of tasks waiting for an item.
		def waiting_count
			@delegate.num_waiting
		end
		
		# Add an item to the queue.
		def push(item)
			@delegate.push(item)
		rescue ClosedQueueError
			raise ClosedError, "Cannot enqueue items to a closed queue!"
		end
		
		# Compatibility with {::Queue#push}.
		def <<(item)
			self.push(item)
		end
		
		# Add multiple items to the queue.
		def enqueue(*items)
			items.each{|item| @delegate.push(item)}
		rescue ClosedQueueError
			raise ClosedError, "Cannot enqueue items to a closed queue!"
		end
		
		# Remove and return the next item from the queue.
		# @parameter timeout [Numeric, nil] Maximum time to wait for an item. If nil, waits indefinitely. If 0, returns immediately.
		# @returns [Object, nil] The dequeued item, or nil if timeout expires.
		def dequeue(timeout: nil)
			@delegate.pop(timeout: timeout)
		end
		
		# Compatibility with {::Queue#pop}.
		# @parameter timeout [Numeric, nil] Maximum time to wait for an item. If nil, waits indefinitely. If 0, returns immediately.
		# @returns [Object, nil] The dequeued item, or nil if timeout expires.
		def pop(timeout: nil)
			@delegate.pop(timeout: timeout)
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
	
	# A thread-safe queue which limits the number of items that can be enqueued.
	#
	# @public Since *Async v1*.
	class LimitedQueue < Queue
		# @private This exists purely for emitting a warning.
		def self.new(...)
			warn("`require 'async/limited_queue'` to use `Async::LimitedQueue`.", uplevel: 1, category: :deprecated) if $VERBOSE
			
			super
		end
		
		# Create a new limited queue.
		#
		# @parameter limit [Integer] The maximum number of items that can be enqueued.
		# @parameter full [Notification] The notification to use for signaling when the queue is full. (ignored, for compatibility)
		def initialize(limit = 1, **options)
			super(**options, delegate: Thread::SizedQueue.new(limit))
		end
		
		# @attribute [Integer] The maximum number of items that can be enqueued.
		def limit
			@delegate.max
		end
		
		# @returns [Boolean] Whether trying to enqueue an item would block.
		def limited?
			!@delegate.closed? && @delegate.size >= @delegate.max
		end
	end
end
