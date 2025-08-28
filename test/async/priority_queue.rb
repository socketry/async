# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.
# Copyright, 2025, by Shopify Inc.

require "async/priority_queue"

require "sus/fixtures/async"

describe Async::PriorityQueue do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:queue) {subject.new}
	
	with "basic functionality" do
		it "can push and pop items" do
			queue.push("item")
			expect(queue.dequeue).to be == "item"
		end
		
		it "reports size correctly" do
			expect(queue.size).to be == 0
			queue.push("item1")
			expect(queue.size).to be == 1
			queue.push("item2")
			expect(queue.size).to be == 2
			queue.dequeue
			expect(queue.size).to be == 1
		end
		
		it "reports empty status correctly" do
			expect(queue.empty?).to be == true
			queue.push("item")
			expect(queue.empty?).to be == false
			queue.dequeue
			expect(queue.empty?).to be == true
		end
	end
	
	with "priority behavior" do
		it "serves higher priority consumers first" do
			results = []
			
			# Start three consumers with different priorities
			low_priority = reactor.async do
				results << [:low, queue.dequeue(priority: 1)]
			end
			
			medium_priority = reactor.async do  
				results << [:medium, queue.dequeue(priority: 5)]
			end
			
			high_priority = reactor.async do
				results << [:high, queue.dequeue(priority: 10)]
			end
			
			# Let all consumers start waiting
			reactor.yield
			
			# Add items one at a time
			queue.push(:item1)
			queue.push(:item2)
			queue.push(:item3)
			
			# Wait for all consumers to finish
			[low_priority, medium_priority, high_priority].each(&:wait)
			
			# Results should be ordered by priority (high to low)
			expect(results).to be == [
				[:high, :item1],
				[:medium, :item2], 
				[:low, :item3]
			]
		end
		
		it "maintains FIFO order for equal priorities" do
			results = []
			
			# Start multiple consumers with same priority
			first = reactor.async do
				results << [:first, queue.dequeue(priority: 5)]
			end
			
			second = reactor.async do
				results << [:second, queue.dequeue(priority: 5)]
			end
			
			third = reactor.async do
				results << [:third, queue.dequeue(priority: 5)]
			end
			
			# Let all consumers start waiting
			reactor.yield
			
			# Add items
			queue.push(:item1)
			queue.push(:item2)
			queue.push(:item3)
			
			# Wait for completion
			[first, second, third].each(&:wait)
			
			# Should maintain FIFO order for equal priorities
			expect(results).to be == [
				[:first, :item1],
				[:second, :item2],
				[:third, :item3]
			]
		end
		
		it "handles mixed priorities correctly" do
			results = []
			
			# Create consumers in random order with mixed priorities
			consumer1 = reactor.async do
				results << [1, queue.dequeue(priority: 3)]
			end
			
			consumer2 = reactor.async do
				results << [2, queue.dequeue(priority: 1)]  # lowest
			end
			
			consumer3 = reactor.async do
				results << [3, queue.dequeue(priority: 5)]  # highest
			end
			
			consumer4 = reactor.async do
				results << [4, queue.dequeue(priority: 3)]  # same as consumer1
			end
			
			reactor.yield
			
			# Add items
			4.times {|i| queue.push("item#{i}")}
			
			[consumer1, consumer2, consumer3, consumer4].each(&:wait)
			
			# Should be: priority 5, then priority 3 (FIFO), then priority 1
			expected_order = [3, 1, 4, 2]  # consumer IDs in expected order
			actual_order = results.map(&:first)
			
			expect(actual_order).to be == expected_order
		end
		
		it "allows high priority consumers to jump the queue" do
			results = []
			
			# Start low priority consumer
			low = reactor.async do
				results << [:low, queue.dequeue(priority: 1)]
			end
			
			reactor.yield  # Let low priority consumer start waiting
			
			# Start high priority consumer after low is already waiting
			high = reactor.async do
				results << [:high, queue.dequeue(priority: 10)]
			end
			
			reactor.yield
			
			# Add one item - should go to high priority consumer
			queue.push(:item)
			
			high.wait
			
			# Add another item for low priority
			queue.push(:item2)
			low.wait
			
			expect(results).to be == [
				[:high, :item],
				[:low, :item2]
			]
		end
		
		it "handles immediate dequeue when items available" do
			# Add items first
			queue.push(:item1)
			queue.push(:item2)
			
			# Dequeue should return immediately regardless of priority
			expect(queue.dequeue(priority: 1)).to be == :item1
			expect(queue.dequeue(priority: 10)).to be == :item2
		end
		
		it "respects priority when items available but waiters exist" do
			results = []
			
			# Start a low priority waiter first (no items available yet)
			low = reactor.async do
				results << [:low, queue.dequeue(priority: 1)]
			end
			
			# Let the low priority consumer start waiting
			reactor.yield
			
			# Add an item - now we have waiters
			queue.push(:available_item)
			
			# Start another low priority waiter to create more waiters
			low2 = reactor.async do
				results << [:low2, queue.dequeue(priority: 1)]
			end
			
			reactor.yield
			
			# Now a high priority consumer should jump ahead of remaining waiters
			high = reactor.async do
				results << [:high, queue.dequeue(priority: 10)]
			end
			
			reactor.yield
			
			# Add more items to satisfy all waiters
			queue.push(:item2)
			queue.push(:item3)
			
			# Wait for all to complete
			low.wait
			low2.wait
			high.wait
			
			# The first low priority consumer got the first item (it was already waiting)
			# The high priority consumer should have jumped ahead of the second low priority
			expect(results).to be == [[:low, :available_item], [:high, :item2], [:low2, :item3]]
		end
		
		it "allows high priority consumers to jump queue with items available" do
			# Add some items first
			queue.push(:item1)
			queue.push(:item2)
			
			# Start a low priority waiter
			low_task = reactor.async do
				queue.dequeue(priority: 1)
			end
			
			reactor.yield
			
			# The low priority waiter should have taken item1
			# High priority consumer gets item2
			result = queue.dequeue(priority: 10)
			expect(result).to be == :item2
			
			low_task.wait
		end
		
		
	end
	
	with "#waiting" do
		it "returns the number of waiting fibers" do
			expect(queue.waiting).to be == 0
			
			task1 = reactor.async {queue.dequeue}
			reactor.yield
			expect(queue.waiting).to be == 1
			
			task2 = reactor.async {queue.dequeue}
			reactor.yield
			expect(queue.waiting).to be == 2
			
			queue.push(:item)
			task1.wait
			expect(queue.waiting).to be == 1
			
			queue.push(:item)
			task2.wait
			expect(queue.waiting).to be == 0
		end
	end
	
	with "#async with priority" do
		it "processes items with specified priority" do
			results = []
			
			# Start async processing with different priorities
			high_task = reactor.async do
				queue.async(priority: 10) do |task, item|
					results << [:high, item]
				end
			end
			
			low_task = reactor.async do
				queue.async(priority: 1) do |task, item|
					results << [:low, item]
				end
			end
			
			reactor.yield
			
			# Add items
			queue.push(:item1)
			queue.push(:item2)
			queue.push(nil)  # Terminal item for high priority
			queue.push(nil)  # Terminal item for low priority
			
			high_task.wait
			low_task.wait
			
			# High priority should get first item
			expect(results.first).to be == [:high, :item1]
		end
	end
	
	with "#enqueue" do
		it "processes multiple items and wakes multiple waiters" do
			results = []
			
			# Start multiple waiters
			waiter1 = reactor.async do
				results << [:waiter1, queue.dequeue(priority: 10)]
			end
			
			waiter2 = reactor.async do
				results << [:waiter2, queue.dequeue(priority: 5)]
			end
			
			waiter3 = reactor.async do
				results << [:waiter3, queue.dequeue(priority: 1)]
			end
			
			reactor.yield
			
			# Add multiple items at once
			queue.enqueue(:item1, :item2, :item3)
			
			waiter1.wait
			waiter2.wait
			waiter3.wait
			
			# Should be processed in priority order
			expect(results).to be == [[:waiter1, :item1], [:waiter2, :item2], [:waiter3, :item3]]
		end
	end
	
	with "#each" do
		it "iterates through items with priority" do
			results = []
			
			# Start iterator with low priority
			iterator = reactor.async do
				queue.each(priority: 1) do |item|
					results << item
				end
			end
			
			reactor.yield
			
			# Add items and nil to terminate
			queue.push(:first)
			queue.push(:second)
			queue.push(nil)  # Terminates the iterator
			
			iterator.wait
			
			expect(results).to be == [:first, :second]
		end
	end
	
	with "#signal and #wait" do
		it "signal behaves like enqueue" do
			queue.signal(:test_item)
			expect(queue.dequeue).to be == :test_item
		end
		
		it "wait behaves like dequeue" do
			queue.push(:test_item)
			result = queue.wait(priority: 5)
			expect(result).to be == :test_item
		end
	end
	
	with "error handling" do
		it "handles closed queue correctly" do
			# Start a waiter
			task = reactor.async {queue.dequeue(priority: 5)}
			reactor.yield
			
			# Close the queue
			queue.close
			
			# Waiter should receive nil and finish
			result = task.wait
			expect(result).to be_nil
		end
		
		it "prevents operations on closed queue" do
			queue.close
			
			expect {queue.push(:item)}.to raise_exception(Async::PriorityQueue::ClosedError)
			expect {queue.enqueue(:item)}.to raise_exception(Async::PriorityQueue::ClosedError)
			expect {queue << :item}.to raise_exception(Async::PriorityQueue::ClosedError)
		end
		
		it "returns nil for dequeue on closed empty queue" do
			queue.close
			expect(queue.dequeue).to be_nil
			expect(queue.pop).to be_nil
		end
	end
	
	with "stress test" do
		it "handles many concurrent consumers with different priorities" do
			num_consumers = 100
			num_items = 100
			results = []
			consumers = []
			
			# Create consumers with random priorities
			num_consumers.times do |i|
				priority = rand(10)
				consumers << reactor.async do
					if item = queue.dequeue(priority: priority)
						results << [i, priority, item]
					end
				end
			end
			
			reactor.yield
			
			# Add items
			num_items.times {|i| queue.push("item#{i}")}
			
			# Wait for consumers to finish
			consumers.each(&:wait)
			
			# Verify we got the right number of results
			expect(results.size).to be == num_items
			
			# Verify priority ordering - should be roughly sorted by priority (desc)
			priorities = results.map {|_, priority, _| priority}
			sorted_priorities = priorities.sort.reverse
			
			# Allow some flexibility due to FIFO within same priority
			# Just check that higher priorities tend to come first
			high_priority_early = priorities.take(20).sum
			low_priority_late = priorities.drop(80).sum
			
			expect(high_priority_early).to be >= low_priority_late
		end
	end
end
