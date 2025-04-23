# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "async/barrier"
require "async/clock"
require "sus/fixtures/async"
require "sus/fixtures/time"
require "async/semaphore"

require "async/chainable_async"

describe Async::Barrier do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:barrier) {subject.new}
	
	with "#async" do
		let(:repeats) {40}
		let(:delay) {0.01}
		
		it "should wait for all jobs to complete" do
			finished = 0
			
			repeats.times.map do |i|
				barrier.async do |task|
					sleep(delay)
					finished += 1
					
					# This task is a child task but not part of the barrier.
					task.async do
						sleep(delay*3)
					end
				end
			end
			
			expect(barrier).not.to be(:empty?)
			expect(finished).to be < repeats
			
			duration = Async::Clock.measure{barrier.wait}
			
			expect(duration).to be_within(repeats * Sus::Fixtures::Time::QUANTUM).of(delay)
			expect(finished).to be == repeats
			expect(barrier).to be(:empty?)
		end
	end
	
	with "#wait" do
		it "should wait for tasks even after exceptions" do
			task1 = barrier.async do |task|
				expect(task).to receive(:warn).and_return(nil)
				
				raise "Boom"
			end
			
			task2 = barrier.async do
			end
			
			expect{barrier.wait}.to raise_exception(RuntimeError, message: be =~ /Boom/)
			
			barrier.wait until barrier.empty?
			
			expect{task1.wait}.to raise_exception(RuntimeError, message: be =~ /Boom/)
			
			expect(barrier).to be(:empty?)
			
			expect(task1).to be(:failed?)
			expect(task2).to be(:finished?)
		end
		
		it "waits for tasks in order" do
			order = []
			
			5.times do |i|
				barrier.async do
					order << i
				end
			end
			
			barrier.wait
			
			expect(order).to be == [0, 1, 2, 3, 4]
		end
		
		# It's possible for Barrier#wait to be interrupted with an unexpected exception, and this should not cause the barrier to incorrectly remove that task from the wait list.
		it "waits for tasks with timeouts" do
			repeats = 5
			count = 0
			
			begin
				reactor.with_timeout(repeats/100.0/2) do
					repeats.times do |i|
						barrier.async do |task|
							sleep(i/100.0)
						end
					end
					
					expect(barrier.tasks.size).to be == repeats
					
					barrier.wait do |task|
						task.wait
						count += 1
					end
				end
			rescue Async::TimeoutError
				# Expected.
			ensure
				expect(barrier.tasks.size).to be == (repeats - count)
				barrier.stop
			end
		end
	end
	
	with "#stop" do
		it "can stop several tasks" do
			task1 = barrier.async do |task|
				sleep(10)
			end
			
			task2 = barrier.async do |task|
				sleep(10)
			end
			
			barrier.stop
			
			expect(task1).to be(:stopped?)
			expect(task2).to be(:stopped?)
		end
		
		it "can stop several tasks when waiting on barrier" do
			task1 = barrier.async do |task|
				sleep(10)
			end
			
			task2 = barrier.async do |task|
				sleep(10)
			end
			
			task3 = reactor.async do
				barrier.wait
			end
			
			barrier.stop
			
			task1.wait
			task2.wait
			
			expect(task1).to be(:stopped?)
			expect(task2).to be(:stopped?)
			
			task3.wait
		end
		
		it "several tasks can wait on the same barrier" do
			task1 = barrier.async do |task|
				sleep(10)
			end
			
			task2 = reactor.async do |task|
				barrier.wait
			end
			
			task3 = reactor.async do
				barrier.wait
			end
			
			barrier.stop
			
			task1.wait
			
			expect(task1).to be(:stopped?)
			
			task2.wait
			task3.wait
		end
	end
	
	with "semaphore" do
		let(:capacity) {2}
		let(:semaphore) {Async::Semaphore.new(capacity)}
		let(:repeats) {capacity * 2}
		
		it "should execute several tasks and wait using a barrier" do
			repeats.times do
				barrier.async(parent: semaphore) do |task|
					sleep 0.01
				end
			end
			
			expect(barrier.size).to be == repeats
			barrier.wait
		end
	end
	
	it_behaves_like Async::ChainableAsync
end
