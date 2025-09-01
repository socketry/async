# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.
# Copyright, 2025, by Shopify Inc.

require "async/priority_queue"
require "sus/fixtures/async"

describe Async::PriorityQueue do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:queue) {subject.new}
	
	with "#push" do
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
	
	with "priority" do
		it "serves higher priority consumers first" do
			results = []
			
			# Start three consumers with different priorities:
			low_priority = reactor.async do
				results << [:low, queue.dequeue(priority: 1)]
			end
			
			medium_priority = reactor.async do
				results << [:medium, queue.dequeue(priority: 5)]
			end
			
			high_priority = reactor.async do
				results << [:high, queue.dequeue(priority: 10)]
			end
			
			# Add items one at a time:
			queue.push(:item1)
			queue.push(:item2)
			queue.push(:item3)
			
			# Wait for all consumers to finish:
			[low_priority, medium_priority, high_priority].each(&:wait)
			
			# Results should be ordered by priority (high to low):
			expect(results).to be == [
				[:high, :item1],
				[:medium, :item2], 
				[:low, :item3]
			]
		end
		
		it "maintains FIFO order for equal priorities" do
			results = []
			
			# Start multiple consumers with same priority:
			first = reactor.async do
				results << [:first, queue.dequeue(priority: 5)]
			end
			
			second = reactor.async do
				results << [:second, queue.dequeue(priority: 5)]
			end
			
			third = reactor.async do
				results << [:third, queue.dequeue(priority: 5)]
			end
			
			# Confirm all consumers are waiting:
			expect(queue.waiting).to be == 3
			
			# Add items:
			queue.push(:item1)
			queue.push(:item2)
			queue.push(:item3)
			
			# Wait for completion:
			[first, second, third].each(&:wait)
			
			# Should maintain FIFO order for equal priorities:
			expect(results).to be == [
				[:first, :item1],
				[:second, :item2],
				[:third, :item3]
			]
		end
		
		it "handles mixed priorities correctly" do
			results = []
			
			# Create consumers in random order with mixed priorities:
			consumer1 = reactor.async do
				results << [1, queue.dequeue(priority: 3)]
			end
			
			consumer2 = reactor.async do
				# Lowest priority:
				results << [2, queue.dequeue(priority: 1)]
			end
			
			consumer3 = reactor.async do
				# Highest priority:
				results << [3, queue.dequeue(priority: 5)]
			end
			
			consumer4 = reactor.async do
				# Priority same as consumer1:
				results << [4, queue.dequeue(priority: 3)]
			end
			
			# Confirm all consumers are waiting:
			expect(queue.waiting).to be == 4
			
			# Add items:
			4.times {|i| queue.push("item#{i}")}
			
			[consumer1, consumer2, consumer3, consumer4].each(&:wait)
			
			expect(results).to be == [
				[3, "item0"],
				[1, "item1"],
				[4, "item2"],
				[2, "item3"]
			]
		end
		
		it "allows high priority consumers to jump the queue" do
			results = []
			
			# Start low priority consumer:
			low = reactor.async do
				results << [:low, queue.dequeue(priority: 1)]
			end
			
			# Start high priority consumer after low is already waiting:
			high = reactor.async do
				results << [:high, queue.dequeue(priority: 10)]
			end
			
			expect(queue.waiting).to be == 2
			
			# Add one item - should go to high priority consumer:
			queue.push(:item)
			
			high.wait
			
			# Add another item for low priority:
			queue.push(:item2)
			low.wait
			
			expect(results).to be == [
				[:high, :item],
				[:low, :item2]
			]
		end
		
		it "handles immediate dequeue when items available" do
			# Add items first:
			queue.push(:item1)
			queue.push(:item2)
			
			# Dequeue should return immediately regardless of priority:
			expect(queue.dequeue(priority: 1)).to be == :item1
			expect(queue.dequeue(priority: 10)).to be == :item2
		end
		
		it "respects priority when items available but waiters exist" do
			results = []
			
			# Start a low priority waiter first (no items available yet):
			low = reactor.async do
				results << [:low, queue.dequeue(priority: 1)]
			end
			
			# Confirm low priority consumer is waiting:
			expect(queue.waiting).to be == 1
			
			# Add an item - now we have waiters:
			queue.push(:available_item)
			
			# Start another low priority waiter to create more waiters:
			low2 = reactor.async do
				results << [:low2, queue.dequeue(priority: 1)]
			end
			
			# Confirm second low priority consumer is waiting (first one got the item):
			expect(queue.waiting).to be == 1
			
			# Now a high priority consumer should jump ahead of remaining waiters:
			high = reactor.async do
				results << [:high, queue.dequeue(priority: 10)]
			end
			
			# Confirm high priority consumer is also waiting (total 2 waiting):
			expect(queue.waiting).to be == 2
			
			# Add more items to satisfy all waiters:
			queue.push(:item2)
			queue.push(:item3)
			
			# Wait for all to complete:
			low.wait
			low2.wait
			high.wait
			
			# The first low priority consumer got the first item (it was already waiting).
			# The high priority consumer should have jumped ahead of the second low priority:
			expect(results).to be == [
				[:low, :available_item],
				[:high, :item2],
				[:low2, :item3]
			]
		end
		
		it "allows high priority consumers to jump queue with items available" do
			# Add some items first:
			queue.push(:item1)
			queue.push(:item2)
			
			# Start a low priority waiter:
			low_task = reactor.async do
				queue.dequeue(priority: 1)
			end
			
			# Confirm low priority waiter got item1 and finished:
			expect(queue.waiting).to be == 0
			
			# The low priority waiter should have taken item1.
			# High priority consumer gets item2:
			result = queue.dequeue(priority: 10)
			expect(result).to be == :item2
			
			low_task.wait
		end
		
		
	end
	
	with "#waiting" do
		it "returns the number of waiting fibers" do
			expect(queue.waiting).to be == 0
			
			task1 = reactor.async {queue.dequeue}
			expect(queue.waiting).to be == 1
			
			task2 = reactor.async {queue.dequeue}
			expect(queue.waiting).to be == 2
			
			queue.push(:item)
			task1.wait
			expect(queue.waiting).to be == 1
			
			queue.push(:item)
			task2.wait
			expect(queue.waiting).to be == 0
		end
	end
	
	with "#async" do
		it "processes items with specified priority" do
			results = []
			
			# Start async processing with different priorities:
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
			
			# Confirm both async tasks are waiting:
			expect(queue.waiting).to be == 2
			
			# Add items:
			queue.push(:item1)
			queue.push(:item2)
			queue.close
			
			high_task.wait
			low_task.wait
			
			# High priority should get first item:
			expect(results.first).to be == [:high, :item1]
		end
	end
	
	with "#enqueue" do
		it "processes multiple items and wakes multiple waiters" do
			results = []
			
			# Start multiple waiters:
			waiter1 = reactor.async do
				results << [:waiter1, queue.dequeue(priority: 10)]
			end
			
			waiter2 = reactor.async do
				results << [:waiter2, queue.dequeue(priority: 5)]
			end
			
			waiter3 = reactor.async do
				results << [:waiter3, queue.dequeue(priority: 1)]
			end
			
			# Confirm all waiters are ready:
			expect(queue.waiting).to be == 3
			
			# Add multiple items at once:
			queue.enqueue(:item1, :item2, :item3)
			
			waiter1.wait
			waiter2.wait
			waiter3.wait
			
			# Should be processed in priority order:
			expect(results).to be == [
				[:waiter1, :item1],
				[:waiter2, :item2],
				[:waiter3, :item3]
			]
		end
	end
	
	with "#each" do
		it "iterates through items with priority" do
			results = []
			
			# Start iterator with low priority:
			iterator = reactor.async do
				queue.each(priority: 1) do |item|
					results << item
				end
			end
			
			# Confirm iterator is waiting:
			expect(queue.waiting).to be == 1
			
			# Add items and nil to terminate:
			queue.push(:first)
			queue.push(:second)
			queue.close
			
			iterator.wait
			
			expect(results).to be == [:first, :second]
		end
	end
	
	with "#signal" do
		it "signal behaves like enqueue" do
			queue.signal(:test_item)
			expect(queue.dequeue).to be == :test_item
		end
	end
	
	with "#wait" do
		it "wait behaves like dequeue" do
			queue.push(:test_item)
			result = queue.wait(priority: 5)
			expect(result).to be == :test_item
		end
	end
	
	with "error handling" do
		it "handles closed queue correctly" do
			# Start a waiter:
			task = reactor.async {queue.dequeue(priority: 5)}
			
			# Confirm waiter is ready:
			expect(queue.waiting).to be == 1
			
			# Close the queue:
			queue.close
			
			# Waiter should receive nil and finish:
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
			
			# Create consumers with random priorities:
			num_consumers.times do |i|
				priority = rand(10)
				consumers << reactor.async do
					if item = queue.dequeue(priority: priority)
						results << [i, priority, item]
					end
				end
			end
			
			# Confirm all consumers are waiting:
			expect(queue.waiting).to be == num_consumers
			
			# Add items:
			num_items.times {|i| queue.push("item#{i}")}
			
			# Wait for consumers to finish:
			consumers.each(&:wait)
			
			# Verify we got the right number of results:
			expect(results.size).to be == num_items
			
			# Verify priority ordering - should be roughly sorted by priority (desc):
			priorities = results.map {|_, priority, _| priority}
			sorted_priorities = priorities.sort.reverse
			
			# Allow some flexibility due to FIFO within same priority.
			# Just check that higher priorities tend to come first:
			high_priority_early = priorities.take(20).sum
			low_priority_late = priorities.drop(80).sum
			
			expect(high_priority_early).to be >= low_priority_late
		end
	end
	
	with "stopped waiters" do
		it "does not consume items when waiters are stopped" do
			# Start a waiter:
			task = reactor.async {queue.dequeue(priority: 5)}
			
			# Confirm waiter is waiting:
			expect(queue.waiting).to be == 1
			
			# Stop the waiting task:
			task.stop
			
			# Add an item - the dead waiter should not consume it:
			queue.push(:test_item)
			
			# The item should still be available for live consumers:
			result = queue.dequeue
			expect(result).to be == :test_item
		end
		
		it "does not waste items on dead waiters" do
			# Start a waiter:
			task = reactor.async {queue.dequeue(priority: 5)}
			
			# Confirm waiter is waiting:
			expect(queue.waiting).to be == 1
			
			# Stop the waiting task:
			task.stop
			
			# Add an item:
			queue.push(:test_item)
			
			# A live waiter should be able to get the item:
			result = queue.dequeue
			expect(result).to be == :test_item
		end
		
		it "handles multiple stopped waiters correctly" do
			results = []
			
			# Start multiple waiters:
			task1 = reactor.async {results << [:task1, queue.dequeue(priority: 10)]}
			task2 = reactor.async {results << [:task2, queue.dequeue(priority: 5)]}
			task3 = reactor.async {results << [:task3, queue.dequeue(priority: 1)]}
			
			# Confirm all three are waiting:
			expect(queue.waiting).to be == 3
			
			# Stop first two tasks:
			task1.stop
			task2.stop
			
			# Add items - only task3 should get them:
			queue.push(:item1)
			queue.push(:item2)
			
			task3.wait
			
			# BUG: Currently stopped waiters consume items:
			expect(results).to be == [[:task3, :item1]]  # Should get first item
			expect(queue.size).to be == 1  # Second item should remain
			expect(queue.waiting).to be == 0  # No waiters should remain
		end
		
		it "maintains correct priority order with stopped waiters" do
			results = []
			
			# Start waiters: low, high, medium priority:
			low_task = reactor.async {results << [:low, queue.dequeue(priority: 1)]}
			high_task = reactor.async {results << [:high, queue.dequeue(priority: 10)]}
			medium_task = reactor.async {results << [:medium, queue.dequeue(priority: 5)]}
			
			# Confirm all are waiting:
			expect(queue.waiting).to be == 3
			
			# Stop the high priority waiter (should have been first):
			high_task.stop
			
			# Add items:
			queue.push(:item1)
			queue.push(:item2)
			
			medium_task.wait
			low_task.wait
			
			expect(results).to be == [
				[:medium, :item1],
				[:low, :item2]
			]
		end
	end
end
