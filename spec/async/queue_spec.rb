# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.
# Copyright, 2019, by Ryan Musgrave.
# Copyright, 2020-2022, by Bruno Sutic.

require 'async'
require 'async/queue'
require 'async/rspec'
require 'async/semaphore'

require_relative 'condition_examples'
require_relative 'chainable_async_examples'

RSpec.shared_context Async::Queue do
	describe '#each' do
		it 'can enumerate queue items' do
			reactor.async do |task|
				10.times do |item|
					task.sleep(0.0001)
					subject.enqueue(item)
				end
				
				subject.enqueue(nil)
			end
			
			items = []
			subject.each do |item|
				items << item
			end
			
			expect(items).to be == 10.times.to_a
		end
	end
	
	it 'should process items in order' do
		reactor.async do |task|
			10.times do |i|
				task.sleep(0.001)
				subject.enqueue(i)
			end
		end
		
		10.times do |j|
			expect(subject.dequeue).to be == j
		end
	end
	
	it 'can enqueue multiple items' do
		items = Array.new(10) { rand(10) }

		reactor.async do |task|
			subject.enqueue(*items)
		end

		items.each do |item|
			expect(subject.dequeue).to be == item
		end
	end
	
	it 'can dequeue items asynchronously' do
		reactor.async do |task|
			subject << 1
			subject << nil
		end
		
		subject.async do |task, item|
			expect(item).to be 1
		end
	end
	
	describe '#<<' do
		it 'adds an item to the queue' do
			subject << :item
			expect(subject.size).to be == 1
			expect(subject.dequeue).to be == :item
		end
	end
	
	describe '#size' do
		it 'returns queue size' do
			expect(subject.size).to be == 0
			subject.enqueue("Hello World")
			expect(subject.size).to be == 1
		end
	end
	
	context 'with an empty queue' do
		it {is_expected.to be_empty}
	end
	
	context 'with semaphore' do
		let(:capacity) {2}
		let(:semaphore) {Async::Semaphore.new(capacity)}
		let(:repeats) {capacity * 2}
		
		it 'should process several items limited by a semaphore' do
			count = 0
			
			Async do
				repeats.times do
					subject.enqueue :item
				end
				
				subject.enqueue nil
			end
			
			subject.async(parent: semaphore) do |task|
				count += 1
			end
			
			expect(count).to be == repeats
		end
	end
	
	it_behaves_like 'chainable async' do
		before do
			subject.enqueue(:item)
			
			# The limited queue may block.
			Async do
				subject.enqueue(nil)
			end
		end
	end
end

RSpec.describe Async::Queue do
	include_context Async::RSpec::Reactor
	
	it_behaves_like Async::Queue
end

RSpec.describe Async::LimitedQueue do
	include_context Async::RSpec::Reactor
	
	it_behaves_like Async::Queue
	
	it 'should become limited' do
		expect(subject).to_not be_limited
		subject.enqueue(10)
		expect(subject).to be_limited
	end
	
	it 'enqueues items up to a limit' do
		items = Array.new(2) { rand(10) }
		reactor.async do
			subject.enqueue(*items)
		end
		
		expect(subject.size).to be 1
		expect(subject.dequeue).to be == items.first
	end
	
	it 'should resume waiting tasks in order' do
		total_resumed = 0
		total_dequeued = 0
		
		Async do |producer|
			10.times do
				producer.async do
					subject.enqueue('foo')
					total_resumed += 1
				end
			end
		end
		
		10.times do
			item = subject.dequeue
			total_dequeued += 1
			
			expect(total_resumed).to be == total_dequeued
		end
	end
	
	describe '#<<' do
		context 'when queue is limited' do
			before do
				subject << :item1
				expect(subject.size).to be == 1
				expect(subject).to be_limited
			end
			
			it 'waits until a queue is dequeued' do
				reactor.async do
					subject << :item2
				end
				
				reactor.async do |task|
					task.sleep 0.01
					expect(subject.items).to contain_exactly :item1
					subject.dequeue
					expect(subject.items).to contain_exactly :item2
				end
			end
		end
	end
end
