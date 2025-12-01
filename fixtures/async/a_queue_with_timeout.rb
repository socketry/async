# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/async"

module Async
	AQueueWithTimeout = Sus::Shared("a queue with timeout support") do
		include Sus::Fixtures::Async::ReactorContext
		
		let(:queue) {subject.new}
		
		with "timeout support" do
			it "supports timeout: 0 for non-blocking dequeue" do
				# Empty queue should return nil immediately
				result = queue.dequeue(timeout: 0)
				expect(result).to be_nil
				
				# With item, should return immediately
				queue.push("item")
				result = queue.dequeue(timeout: 0)
				expect(result).to be == "item"
			end
			
			it "supports timeout: 0 for non-blocking pop" do
				# Empty queue should return nil immediately
				result = queue.pop(timeout: 0)
				expect(result).to be_nil
				
				# With item, should return immediately
				queue.push("item")
				result = queue.pop(timeout: 0)
				expect(result).to be == "item"
			end
			
			it "supports positive timeout values" do
				start_time = Time.now
				
				# Should timeout after specified time
				result = queue.dequeue(timeout: 0.1)
				elapsed = Time.now - start_time
				
				expect(result).to be_nil
				expect(elapsed).to be >= 0.1
			end
			
			it "returns item before timeout expires" do
				result = nil
				
				# Start dequeue with timeout in background
				task = reactor.async do
					result = queue.dequeue(timeout: 1.0)
				end
				
				# Add item quickly
				reactor.sleep(0.05)
				queue.push("quick_item")
				
				task.wait
				expect(result).to be == "quick_item"
			end
			
			it "handles concurrent timeouts" do
				results = []
				
				# Start multiple consumers with different timeouts
				task1 = reactor.async do
					results << [:task1, queue.dequeue(timeout: 0.1)]
				end
				
				task2 = reactor.async do
					results << [:task2, queue.dequeue(timeout: 0.2)]
				end
				
				task3 = reactor.async do
					results << [:task3, queue.dequeue(timeout: 0.3)]
				end
				
				# Wait for all to timeout
				[task1, task2, task3].each(&:wait)
				
				# All should have timed out
				expect(results).to be == [
					[:task1, nil],
					[:task2, nil],
					[:task3, nil]
				]
			end
			
			it "preserves FIFO order when items arrive before timeout" do
				results = []
				
				# Start multiple consumers with same timeout
				tasks = 3.times.map do |i|
					reactor.async do
						results << [i, queue.dequeue(timeout: 1.0)]
					end
				end
				
				# Add items quickly
				reactor.sleep(0.05)
				queue.push("item1")
				queue.push("item2")
				queue.push("item3")
				
				tasks.each(&:wait)
				
				# Should maintain FIFO order
				expect(results).to be == [
					[0, "item1"],
					[1, "item2"],
					[2, "item3"]
				]
			end
		end
	end
end
