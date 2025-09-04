# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "io/event/priority_heap"
require "thread"

require_relative "queue"

module Async
	# A queue which allows items to be processed in priority order of consumers.
	#
	# Unlike a traditional priority queue where items have priorities, this queue 
	# assigns priorities to consumers (fibers waiting to dequeue). Higher priority
	# consumers are served first when items become available.
	#
	# @public Since *Async v2*.
	class PriorityQueue
		ClosedError = Queue::ClosedError
		
		# A waiter represents a fiber waiting to dequeue with a given priority.
		Waiter = Struct.new(:fiber, :priority, :sequence, :condition, :value) do
			include Comparable
			
			def <=>(other)
				# Higher priority comes first, then FIFO for equal priorities:
				if priority == other.priority
					# Use sequence for FIFO behavior (lower sequence = earlier):
					sequence <=> other.sequence
				else
					other.priority <=> priority  # Reverse for max-heap behavior
				end
			end
			
			def signal(value)
				self.value = value
				condition.signal
			end
			
			def wait_for_value(mutex)
				condition.wait(mutex)
				return self.value
			end
		end
		
		# Create a new priority queue.
		#
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		def initialize(parent: nil)
			@items = []
			@closed = false
			@parent = parent
			@waiting = IO::Event::PriorityHeap.new
			@sequence = 0
			
			@mutex = Mutex.new
		end
		
		# Close the queue, causing all waiting tasks to return `nil`. 
		# Any subsequent calls to {enqueue} will raise an exception.
		def close
			@mutex.synchronize do
				@closed = true
				
				# Signal all waiting fibers with nil, skipping dead ones:
				while waiter = @waiting.pop
					if waiter.fiber.alive?
						waiter.signal(nil)
					end
					# Dead waiter discarded, continue to next one.
				end
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
		
		# @returns [Integer] The number of fibers waiting to dequeue.
		def waiting
			@mutex.synchronize do
				@waiting.size
			end
		end
		
		# Add an item to the queue.
		#
		# @parameter item [Object] The item to add to the queue.
		def push(item)
			@mutex.synchronize do
				if @closed
					raise ClosedError, "Cannot push items to a closed queue."
				end
				
				@items << item
				
				# Wake up the highest priority waiter if any, skipping dead waiters:
				while waiter = @waiting.pop
					if waiter.fiber.alive?
						value = @items.shift
						waiter.signal(value)
						break
					end
					# Dead waiter discarded, try next one.
				end
			end
		end
		
		# Compatibility with {::Queue#push}.
		def <<(item)
			self.push(item)
		end
		
		# Add multiple items to the queue.
		#
		# @parameter items [Array] The items to add to the queue.
		def enqueue(*items)
			@mutex.synchronize do
				if @closed
					raise ClosedError, "Cannot enqueue items to a closed queue."
				end
				
				@items.concat(items)
				
				# Wake up waiting fibers in priority order, skipping dead waiters:
				while !@items.empty? && (waiter = @waiting.pop)
					if waiter.fiber.alive?
						value = @items.shift
						waiter.signal(value)
					end
					# Dead waiter discarded, continue to next one.
				end
			end
		end
		
		# Remove and return the next item from the queue.
		#
		# If the queue is empty, this method will block until an item is available.
		# Fibers are served in priority order, with higher priority fibers receiving
		# items first.
		#
		# @parameter priority [Numeric] The priority of this consumer (higher = served first).
		# @returns [Object] The next item in the queue.
		def dequeue(priority: 0)
			@mutex.synchronize do
				# If queue is closed and empty, return nil immediately:
				if @closed && @items.empty?
					return nil
				end
				
				# Fast path: if items available and either no waiters or we have higher priority:
				unless @items.empty?
					head = @waiting.peek
					if head.nil? or priority > head.priority
						return @items.shift
					end
				end
				
				# Need to wait - create our own condition variable and add to waiting queue:
				sequence = @sequence
				@sequence += 1
				
				condition = ConditionVariable.new
				waiter = Waiter.new(Fiber.current, priority, sequence, condition, nil)
				@waiting.push(waiter)
				
				# Wait for our specific condition variable to be signaled:
				# The mutex is released during wait, reacquired after:
				return waiter.wait_for_value(@mutex)
			end
		end
		
		# Compatibility with {::Queue#pop}.
		#
		# @parameter priority [Numeric] The priority of this consumer.
		def pop(priority: 0)
			self.dequeue(priority: priority)
		end
		
		# Process each item in the queue.
		#
		# @asynchronous Executes the given block concurrently for each item.
		#
		# @parameter priority [Numeric] The priority for processing items.
		# @parameter parent [Interface(:async) | Nil] The parent task to use for async operations.
		# @parameter options [Hash] The options to pass to the task.
		# @yields {|task| ...} When the system is idle, the block will be executed in a new task.
		def async(priority: 0, parent: (@parent or Task.current), **options, &block)
			while item = self.dequeue(priority: priority)
				parent.async(item, **options, &block)
			end
		end
		
		# Enumerate each item in the queue.
		#
		# @parameter priority [Numeric] The priority for dequeuing items.
		def each(priority: 0)
			while item = self.dequeue(priority: priority)
				yield item
			end
		end
		
		# Signal the queue with a value, the same as {#enqueue}.
		def signal(value = nil)
			self.enqueue(value)
		end
		
		# Wait for an item to be available, the same as {#dequeue}.
		#
		# @parameter priority [Numeric] The priority of this consumer.
		def wait(priority: 0)
			self.dequeue(priority: priority)
		end
	end
end
