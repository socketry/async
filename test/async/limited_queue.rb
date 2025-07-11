# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/limited_queue"

require "sus/fixtures/async"
require "async/a_queue"

describe Async::LimitedQueue do
	include Sus::Fixtures::Async::ReactorContext
	
	it_behaves_like Async::AQueue
	
	let(:queue) {subject.new}
	
	it "should become limited" do
		expect(queue).not.to be(:limited?)
		queue.enqueue(10)
		expect(queue).to be(:limited?)
	end
	
	it "enqueues items up to a limit" do
		items = Array.new(2) {rand(10)}
		reactor.async do
			queue.enqueue(*items)
		end
		
		expect(queue.size).to be == 1
		expect(queue.dequeue).to be == items.first
	end
	
	it "should resume waiting tasks in order" do
		total_resumed = 0
		total_dequeued = 0
		
		Async do |producer|
			10.times do
				producer.async do
					queue.enqueue("foo")
					total_resumed += 1
				end
			end
		end
		
		10.times do
			queue.dequeue
			total_dequeued += 1
			
			expect(total_resumed).to be == total_dequeued
		end
	end
	
	with "#<<" do
		with "a limited queue" do
			def before
				queue << :item1
				expect(queue.size).to be == 1
				expect(queue).to be(:limited?)
				
				super
			end
			
			it "waits until a queue is dequeued" do
				reactor.async do
					queue << :item2
				end
				
				expect(queue.dequeue).to be == :item1
				expect(queue.dequeue).to be == :item2
			end

			with "#pop" do
				it "waits until a queue is dequeued" do
					reactor.async do
						queue << :item2
					end
					
					expect(queue.pop).to be == :item1
					expect(queue.pop).to be == :item2
				end
			end
		end
	end

	with "#close" do
		it "signals tasks waiting to enqueue items when closed" do
			queue.enqueue(:item1)

			# This task will block as the queue is full:
			waiting_task = reactor.async do
				queue.enqueue(:item2)
			end

			queue.close

			expect do
				waiting_task.wait
			end.to raise_exception(Async::Queue::ClosedError)
		end
	end
end

