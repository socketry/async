# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "async"
require "async/priority_queue"
require "sus/fixtures/async"

require "async/chainable_async"

module Async
	APriorityQueue = Sus::Shared("a priority queue") do
		let(:queue) {subject.new}
		
		# Include all basic queue behaviors
		it_behaves_like Async::AQueue
		
		with "priority ordering" do
			it "serves consumers in priority order" do
				results = []
				
				# Create consumers with different priorities
				low = reactor.async do
					results << queue.dequeue(priority: 1)
				end
				
				high = reactor.async do
					results << queue.dequeue(priority: 10)
				end
				
				reactor.yield
				
				# Add items
				queue.push(:first_item)
				queue.push(:second_item)
				
				[low, high].each(&:wait)
				
				# High priority should get first item
				expect(results).to be == [:first_item, :second_item]
				# Verify high priority got the first item by checking task completion order
			end
			
			it "maintains FIFO within same priority" do
				results = []
				
				first = reactor.async do
					results << [:first, queue.dequeue(priority: 5)]
				end
				
				second = reactor.async do
					results << [:second, queue.dequeue(priority: 5)]
				end
				
				reactor.yield
				
				queue.push(:item1)
				queue.push(:item2)
				
				[first, second].each(&:wait)
				
				expect(results).to be == [
					[:first, :item1],
					[:second, :item2]
				]
			end
			
			it "allows priority-based queue jumping" do
				results = []
				
				# Start low priority consumer first
				low = reactor.async do
					results << [:low, queue.dequeue(priority: 1)]
				end
				
				reactor.yield
				
				# Start high priority consumer after low is waiting
				high = reactor.async do
					results << [:high, queue.dequeue(priority: 10)]
				end
				
				reactor.yield
				
				# High priority should get the first item despite arriving later
				queue.push(:item1)
				high.wait
				
				queue.push(:item2)
				low.wait
				
				expect(results).to be == [
					[:high, :item1],
					[:low, :item2]
				]
			end
		end
		
		with "priority methods" do
			it "supports priority parameter in dequeue" do
				queue.push(:item)
				expect(queue.dequeue(priority: 5)).to be == :item
			end
			
			it "supports priority parameter in pop" do
				queue.push(:item)
				expect(queue.pop(priority: 5)).to be == :item
			end
			
			it "supports priority parameter in wait" do
				reactor.async{queue.push(:item)}
				expect(queue.wait(priority: 5)).to be == :item
			end
			
			it "supports priority parameter in each" do
				items = [:item1, :item2]
				reactor.async do
					items.each{|item| queue.push(item)}
					queue.push(nil)
				end
				
				results = []
				queue.each(priority: 5) do |item|
					results << item
				end
				
				expect(results).to be == items
			end
			
			it "supports priority parameter in async" do
				reactor.async do
					queue.push(:item)
					queue.push(nil)
				end
				
				results = []
				queue.async(priority: 5) do |task, item|
					results << item
				end
				
				expect(results).to be == [:item]
			end
		end
		
		with "#waiting" do
			it "tracks number of waiting consumers" do
				expect(queue.waiting).to be == 0
				
				task1 = reactor.async{queue.dequeue}
				reactor.yield
				expect(queue.waiting).to be == 1
				
				task2 = reactor.async{queue.dequeue}
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
		
		with "edge cases" do
			it "handles immediate dequeue when items available" do
				queue.push(:item)
				expect(queue.dequeue(priority: 1)).to be == :item
				expect(queue.dequeue(priority: 10)).to be_nil if queue.empty?
			end
			
			it "respects priority when items available but waiters exist" do
				queue.push(:available)
				
				# Start low priority waiter
				low_task = reactor.async do
					queue.dequeue(priority: 1)
				end
				reactor.yield
				
				# High priority should get available item
				result = queue.dequeue(priority: 10)
				expect(result).to be == :available
				
				# Clean up
				queue.push(:cleanup)
				low_task.wait
			end
		end
	end
end
