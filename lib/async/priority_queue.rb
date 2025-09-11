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
			
			def wait_for_value(mutex, timeout = nil)
				condition.wait(mutex, timeout)
				return self.value
			end
			
			# Invalidate this waiter, making it unusable and detectable as abandoned.
			def invalidate!
				self.fiber = nil
			end
			
			# Check if this waiter has been invalidated.
			def valid?
				self.fiber&.alive?
			end
		end
		
		private_constant :Waiter
		
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
				
				# Signal all waiting fibers with nil, skipping dead/invalid ones:
				while waiter = @waiting.pop
					waiter.signal(nil)
				end
			end
		end
		
		# @returns [Boolean] Whether the queue is closed.
		def closed?
			@closed
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
		def waiting_count
			@mutex.synchronize do
				@waiting.size
			end
		end
		
		# @deprecated Use {#waiting_count} instead.
		alias waiting waiting_count
		
		# Add an item to the queue.
		#
		# @parameter item [Object] The item to add to the queue.
		def push(item)
			@mutex.synchronize do
				if @closed
					raise ClosedError, "Cannot push items to a closed queue."
				end
				
				@items << item
				
				# Wake up the highest priority waiter if any, skipping dead/invalid waiters:
				while waiter = @waiting.pop
					if waiter.valid?
						value = @items.shift
						waiter.signal(value)
						break
					end
					# Dead/invalid waiter discarded, try next one.
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
				
				# Wake up waiting fibers in priority order, skipping dead/invalid waiters:
				while !@items.empty? && (waiter = @waiting.pop)
					if waiter.valid?
						value = @items.shift
						waiter.signal(value)
					end
					# Dead/invalid waiter discarded, continue to next one.
				end
			end
		end
		
		# Remove and return the next item from the queue.
		#
		# If the queue is empty, this method will block until an item is available or timeout expires.
		# Fibers are served in priority order, with higher priority fibers receiving
		# items first.
		#
		# @parameter priority [Numeric] The priority of this consumer (higher = served first).
		# @parameter timeout [Numeric, nil] Maximum time to wait for an item. If nil, waits indefinitely. If 0, returns immediately.
		# @returns [Object, nil] The next item in the queue, or nil if timeout expires.
		def dequeue(priority: 0, timeout: nil)
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
				
				# Handle immediate timeout (non-blocking)
				return nil if timeout == 0
				
				# Need to wait - create our own condition variable and add to waiting queue:
				sequence = @sequence
				@sequence += 1
				
				condition = ConditionVariable.new
				
				begin
					waiter = Waiter.new(Fiber.current, priority, sequence, condition, nil)
					@waiting.push(waiter)
					
					# Wait for our specific condition variable to be signaled:
					return waiter.wait_for_value(@mutex, timeout)
				ensure
					waiter&.invalidate!
				end
			end
		end
		
		# Compatibility with {::Queue#pop}.
		#
		# @parameter priority [Numeric] The priority of this consumer.
		# @parameter timeout [Numeric, nil] Maximum time to wait for an item. If nil, waits indefinitely. If 0, returns immediately.
		# @returns [Object, nil] The dequeued item, or nil if timeout expires.
		def pop(priority: 0, timeout: nil)
			self.dequeue(priority: priority, timeout: timeout)
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
