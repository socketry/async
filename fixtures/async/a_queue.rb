# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async"
require "async/queue"
require "sus/fixtures/async"
require "async/semaphore"

require "async/chainable_async"

module Async
	AQueue = Sus::Shared("a queue") do
		let(:queue) {subject.new}
		
		with "#push" do
			it "adds an item to the queue" do
				queue.push(:item)
				expect(queue.size).to be == 1
				expect(queue.dequeue).to be == :item
			end
		end
		
		with "#pop" do
			it "removes an item from the queue" do
				queue.push(:item)
				expect(queue.pop).to be == :item
				expect(queue.size).to be == 0
			end
		end
		
		with "#each" do
			it "can enumerate queue items" do
				reactor.async do |task|
					10.times do |item|
						sleep(0.0001)
						queue.enqueue(item)
					end
					
					queue.enqueue(nil)
				end
				
				items = []
				queue.each do |item|
					items << item
				end
				
				expect(items).to be == 10.times.to_a
			end
		end
		
		it "should process items in order" do
			reactor.async do |task|
				10.times do |i|
					sleep(0.001)
					queue.enqueue(i)
				end
			end
			
			10.times do |j|
				expect(queue.dequeue).to be == j
			end
		end
		
		it "can enqueue multiple items" do
			items = Array.new(10) { rand(10) }

			reactor.async do |task|
				queue.enqueue(*items)
			end

			items.each do |item|
				expect(queue.dequeue).to be == item
			end
		end
		
		it "can dequeue items asynchronously" do
			reactor.async do |task|
				queue << 1
				queue << nil
			end
			
			queue.async do |task, item|
				expect(item).to be == 1
			end
		end
		
		with "#<<" do
			it "adds an item to the queue" do
				queue << :item
				expect(queue.size).to be == 1
				expect(queue.dequeue).to be == :item
			end
		end
		
		with "#size" do
			it "returns queue size" do
				expect(queue.size).to be == 0
				queue.enqueue("Hello World")
				expect(queue.size).to be == 1
			end
		end
		
		with "#signal" do
			it "can signal with an item" do
				queue.signal(:item)
				expect(queue.dequeue).to be == :item
			end
		end
		
		with "#wait" do
			it "can wait for an item" do
				reactor.async do |task|
					queue.enqueue(:item)
				end
				
				expect(queue.wait).to be == :item
			end
		end
		
		with "an empty queue" do
			it "is expected to be empty" do
				expect(queue).to be(:empty?)
			end
		end
		
		with "task finishing queue" do
			it "can signal task completion" do
				3.times do
					Async(finished: queue) do
						:result
					end
				end
				
				3.times do
					task = queue.dequeue
					expect(task.wait).to be == :result
				end
			end
		end
		
		with "semaphore" do
			let(:capacity) {2}
			let(:semaphore) {Async::Semaphore.new(capacity)}
			let(:repeats) {capacity * 2}
			
			it "should process several items limited by a semaphore" do
				count = 0
				
				Async do
					repeats.times do
						queue.enqueue :item
					end
					
					queue.enqueue nil
				end
				
				queue.async(parent: semaphore) do |task|
					count += 1
				end
				
				expect(count).to be == repeats
			end
		end
		
		it_behaves_like Async::ChainableAsync do
			def before
				chainable.enqueue(:item)
				
				# The limited queue may block.
				Async do
					chainable.enqueue(nil)
				end
				
				super
			end
		end
	end
end
