#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/benchmark"
require "async/condition"
require "async"

describe Async::Condition do
	include Sus::Fixtures::Benchmark
	
	let(:condition) {Async::Condition.new}
	
	with "basic signal and wait operations" do
		measure "signal without waiters" do |repeats|
			test_condition = Async::Condition.new
			
			repeats.times do
				test_condition.signal("value")
			end
		end
		
		measure "simple signal and wait pairs" do |repeats|
			Async do |task|
				signal_counter = 0
				repeats.times do
					waiter = task.async do
						condition.wait
					end
					
					# Signal the waiting fiber
					condition.signal("signal-#{signal_counter}")
					
					waiter.wait
					signal_counter += 1
				end
			end
		end
		
		measure "immediate signal then wait" do |repeats|
			repeats.times do
				test_condition = Async::Condition.new
				
				Async do |task|
					# Signal first, then wait
					test_condition.signal("immediate")
					
					# This should return immediately since already signaled
					waiter = task.async do
						test_condition.wait
					end
					
					waiter.wait
				end
			end
		end
	end
	
	with "multiple waiters scenarios" do
		measure "single signal to multiple waiters" do |repeats|
			repeats.times do
				Async do |task|
					# Create multiple waiters
					waiters = 5.times.map do |i|
						task.async do
							condition.wait
						end
					end
					
					# Single signal should wake all waiters
					condition.signal("broadcast")
					
					# Wait for all waiters to complete
					waiters.each(&:wait)
				end
			end
		end
		
		measure "multiple signals to multiple waiters" do |repeats|
			repeats.times do
				Async do |task|
					# Create waiters
					waiters = 5.times.map do |i|
						task.async do
							condition.wait
						end
					end
					
					# Multiple signals
					5.times do |idx|
						condition.signal("signal-#{idx}")
					end
					
					waiters.each(&:wait)
				end
			end
		end
		
		measure "sequential waiter creation and signaling" do |repeats|
			Async do |task|
				value_counter = 0
				repeats.times do
					# Create waiter
					waiter = task.async do
						condition.wait
					end
					
					# Create signaler
					signaler = task.async do
						sleep(0.001) # Brief delay
						condition.signal("value-#{value_counter}")
					end
					
					[waiter, signaler].each(&:wait)
					value_counter += 1
				end
			end
		end
	end
	
	with "condition state management" do
		measure "empty and waiting state checks" do |repeats|
			repeats.times do
				test_condition = Async::Condition.new
				
				Async do |task|
					# Check empty state
					100.times {test_condition.empty?}
					
					# Create a waiter
					waiter = task.async do
						test_condition.wait
					end
					
					# Check waiting state
					100.times {test_condition.waiting?}
					
					# Signal to complete
					test_condition.signal("done")
					waiter.wait
				end
			end
		end
		
		measure "rapid signal/wait cycling" do |repeats|
			Async do |task|
				repeats.times do
					waiter = task.async do
						condition.wait
					end
					
					condition.signal("cycle")
					waiter.wait
				end
			end
		end
	end
	
	with "high concurrency scenarios" do
		measure "many concurrent waiters", minimum: 3 do |repeats|
			repeats.times do
				Async do |task|
					# Create many waiters
					waiters = 20.times.map do
						task.async do
							condition.wait
						end
					end
					
					# Signal to wake them all
					condition.signal("mass-signal")
					
					# Wait for all to complete
					waiters.each(&:wait)
				end
			end
		end
		
		measure "producer-consumer with condition coordination" do |repeats|
			repeats.times do
				Async do |task|
					ready_condition = Async::Condition.new
					done_condition = Async::Condition.new
					
					# Producer
					producer = task.async do
						ready_condition.wait # Wait for consumer to be ready
						50.times {|i| "item-#{i}"} # Simulate work
						done_condition.signal("finished")
					end
					
					# Consumer  
					consumer = task.async do
						ready_condition.signal("ready") # Signal producer
						done_condition.wait # Wait for completion
					end
					
					[producer, consumer].each(&:wait)
				end
			end
		end
	end
	
	with "memory and cleanup patterns" do
		measure "condition lifecycle" do |repeats|
			repeats.times do
				# Create condition, use it, let it be collected
				test_condition = Async::Condition.new
				
				Async do |task|
					waiter = task.async {test_condition.wait}
					
					test_condition.signal("cleanup")
					waiter.wait
				end
				
				# Condition should be eligible for GC now
			end
		end
		
		measure "signal with different value types" do |repeats|
			Async do |task|
				repeats.times do
					waiter = task.async do
						condition.wait
					end
					
					# Signal with different value types to test overhead
					case value_counter % 4
					when 0
						condition.signal(nil)
					when 1
						condition.signal(value_counter)
					when 2
						condition.signal("string-#{value_counter}")
					when 3
						condition.signal({key: value_counter})
					end
					
					value_counter += 1
					
					waiter.wait
				end
			end
		end
	end
end
