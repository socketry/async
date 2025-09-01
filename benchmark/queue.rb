#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/benchmark"
require "async/queue"
require "async"

describe "Async::Queue Performance" do
	include Sus::Fixtures::Benchmark
	
	let(:queue) {Async::Queue.new}
	
	with "single-threaded operations" do
		measure "enqueue and dequeue pairs" do |repeats|
			Async do
				repeats.times do
					queue.push("item")
					queue.dequeue
				end
			end
		end
		
		measure "batch enqueue" do |repeats|
			repeats.times do
				Async do
					# Create a batch of 100 items each time
					items = Array.new(100) {|i| "item-#{i}"}
					queue.enqueue(*items)
					# Clear queue for next iteration
					100.times {queue.dequeue}
				end
			end
		end
		
		measure "batch dequeue" do |repeats|
			repeats.times do
				Async do
					# Pre-populate queue with 100 items
					items = Array.new(100) {|i| "item-#{i}"}
					queue.enqueue(*items)
					
					# Measure dequeue operations
					100.times do
						queue.dequeue
					end
				end
			end
		end
	end
	
	with "producer-consumer patterns" do
		measure "single producer, single consumer" do |repeats|
			repeats.times do
				Async do |task|
					# Producer
					producer = task.async do
						100.times do |i|
							queue.push("item-#{i}")
						end
						queue.push(nil) # Signal completion
					end
					
					# Consumer
					consumer = task.async do
						count = 0
						while item = queue.dequeue
							count += 1
						end
						count
					end
					
					[producer, consumer].each(&:wait)
				end
			end
		end
		
		measure "multiple producers, single consumer", minimum: 3 do |repeats|
			repeats.times do
				Async do |task|
					num_producers = 4
					items_per_producer = 25 # 100 total items
					
					# Multiple producers
					producers = num_producers.times.map do |i|
						task.async do
							items_per_producer.times do |j|
								queue.push("producer-#{i}-item-#{j}")
							end
						end
					end
					
					# Single consumer
					consumer = task.async do
						total_items = num_producers * items_per_producer
						total_items.times do
							queue.dequeue
						end
					end
					
					producers.each(&:wait)
					consumer.wait
				end
			end
		end
		
		measure "single producer, multiple consumers", minimum: 3 do |repeats|
			repeats.times do
				Async do |task|
					num_consumers = 4
					total_items = 100
					
					# Single producer
					producer = task.async do
						total_items.times do |i|
							queue.push("item-#{i}")
						end
						# Signal completion to all consumers
						num_consumers.times {queue.push(nil)}
					end
					
					# Multiple consumers
					consumers = num_consumers.times.map do
						task.async do
							count = 0
							while item = queue.dequeue
								count += 1
							end
							count
						end
					end
					
					producer.wait
					consumers.each(&:wait)
				end
			end
		end
	end
	
	with "queue size operations" do
		measure "size checks with concurrent modifications" do |repeats|
			repeats.times do
				Async do |task|
					# Pre-populate with some items
					100.times {|i| queue.push("item-#{i}")}
					
					# Reader checking size
					size_checker = task.async do
						100.times do
							queue.size
						end
					end
					
					# Writer modifying queue
					modifier = task.async do
						50.times do |i|
							queue.push("new-item-#{i}")
							queue.dequeue if i.even?
						end
					end
					
					[size_checker, modifier].each(&:wait)
					
					# Clean up
					queue.size.times {queue.dequeue}
				end
			end
		end
	end
	
	with "memory efficiency" do
		measure "queue growth and shrinkage" do |repeats|
			repeats.times do
				Async do
					# Fill the queue
					100.times {|i| queue.push("item-#{i}")}
					
					# Empty the queue  
					100.times {queue.dequeue}
					
					# Fill again to test reuse
					100.times {|i| queue.push("item-#{i}")}
					
					# Empty again
					100.times {queue.dequeue}
				end
			end
		end
	end
end
