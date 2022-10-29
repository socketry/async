# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.
# Copyright, 2019, by Ryan Musgrave.
# Copyright, 2020-2022, by Bruno Sutic.

require 'async'
require 'async/queue'
require 'sus/fixtures/async'
require 'async/semaphore'

require 'chainable_async'

AQueue = Sus::Shared("a queue") do
	let(:queue) {subject.new}
	
	with '#each' do
		it 'can enumerate queue items' do
			reactor.async do |task|
				10.times do |item|
					task.sleep(0.0001)
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
	
	it 'should process items in order' do
		reactor.async do |task|
			10.times do |i|
				task.sleep(0.001)
				queue.enqueue(i)
			end
		end
		
		10.times do |j|
			expect(queue.dequeue).to be == j
		end
	end
	
	it 'can enqueue multiple items' do
		items = Array.new(10) { rand(10) }

		reactor.async do |task|
			queue.enqueue(*items)
		end

		items.each do |item|
			expect(queue.dequeue).to be == item
		end
	end
	
	it 'can dequeue items asynchronously' do
		reactor.async do |task|
			queue << 1
			queue << nil
		end
		
		queue.async do |task, item|
			expect(item).to be == 1
		end
	end
	
	with '#<<' do
		it 'adds an item to the queue' do
			queue << :item
			expect(queue.size).to be == 1
			expect(queue.dequeue).to be == :item
		end
	end
	
	with '#size' do
		it 'returns queue size' do
			expect(queue.size).to be == 0
			queue.enqueue("Hello World")
			expect(queue.size).to be == 1
		end
	end
	
	with 'an empty queue' do
		it {is_expected.to be_empty}
	end
	
	with 'semaphore' do
		let(:capacity) {2}
		let(:semaphore) {Async::Semaphore.new(capacity)}
		let(:repeats) {capacity * 2}
		
		it 'should process several items limited by a semaphore' do
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
	
	with "an item" do
		def before
			queue.enqueue(:item)
			
			# The limited queue may block.
			Async do
				queue.enqueue(nil)
			end
			
			super
		end
		
		it_behaves_like ChainableAsync
	end
end

describe Async::Queue do
	include Sus::Fixtures::Async::ReactorContext
	
	it_behaves_like AQueue
end

describe Async::LimitedQueue do
	include Sus::Fixtures::Async::ReactorContext
	
	it_behaves_like AQueue
	
	let(:queue) {subject.new}
	
	it 'should become limited' do
		expect(queue).not.to be(:limited?)
		queue.enqueue(10)
		expect(queue).to be(:limited?)
	end
	
	it 'enqueues items up to a limit' do
		items = Array.new(2) { rand(10) }
		reactor.async do
			queue.enqueue(*items)
		end
		
		expect(queue.size).to be == 1
		expect(queue.dequeue).to be == items.first
	end
	
	it 'should resume waiting tasks in order' do
		total_resumed = 0
		total_dequeued = 0
		
		Async do |producer|
			10.times do
				producer.async do
					queue.enqueue('foo')
					total_resumed += 1
				end
			end
		end
		
		10.times do
			item = queue.dequeue
			total_dequeued += 1
			
			expect(total_resumed).to be == total_dequeued
		end
	end
	
	with '#<<' do
		with 'a limited queue' do
			def before
				queue << :item1
				expect(queue.size).to be == 1
				expect(queue).to be(:limited?)
				
				super
			end
			
			it 'waits until a queue is dequeued' do
				reactor.async do
					queue << :item2
				end
				
				reactor.async do |task|
					task.sleep 0.01
					expect(queue.items).to contain_exactly :item1
					queue.dequeue
					expect(queue.items).to contain_exactly :item2
				end
			end
		end
	end
end
