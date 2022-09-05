# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require 'async/barrier'
require 'async/clock'
require 'async/rspec'
require 'async/semaphore'

require_relative 'chainable_async_examples'

RSpec.describe Async::Barrier do
	include_context Async::RSpec::Reactor
	
	describe '#async' do
		let(:repeats) {40}
		let(:delay) {0.1}
		
		it 'should wait for all jobs to complete' do
			finished = 0
			
			repeats.times.map do |i|
				subject.async do |task|
					task.sleep(delay)
					finished += 1
					
					# This task is a child task but not part of the barrier.
					task.async do
						task.sleep(delay*3)
					end
				end
			end
			
			expect(subject).to_not be_empty
			expect(finished).to be < repeats
			
			duration = Async::Clock.measure{subject.wait}
			
			expect(duration).to be < (delay * 2 * Q)
			expect(finished).to be == repeats
			expect(subject).to be_empty
		end
	end
	
	describe '#wait' do
		it 'should wait for tasks even after exceptions' do
			task1 = subject.async do
				raise "Boom"
			end
			
			task2 = subject.async do
			end
			
			expect(task1).to be_failed
			expect(task2).to be_finished
			
			expect{subject.wait}.to raise_exception(/Boom/)
			
			subject.wait until subject.empty?
			
			expect(subject).to be_empty
		end
		
		it 'waits for tasks in order' do
			order = []
			
			5.times do |i|
				subject.async do
					order << i
				end
			end
			
			subject.wait
			
			expect(order).to be == [0, 1, 2, 3, 4]
		end
		
		# It's possible for Barrier#wait to be interrupted with an unexpected exception, and this should not cause the barrier to incorrectly remove that task from the wait list.
		it 'waits for tasks with timeouts' do
			begin
				reactor.with_timeout(0.25) do
					5.times do |i|
						subject.async do |task|
							task.sleep(i/10.0)
						end
					end
					
					expect(subject.tasks.size).to be == 5
					subject.wait
				end
			rescue Async::TimeoutError
				# Expected.
			ensure
				expect(subject.tasks.size).to be == 2
				subject.stop
			end
		end
	end
	
	describe '#stop' do
		it "can stop several tasks" do
			task1 = subject.async do |task|
				task.sleep(10)
			end
			
			task2 = subject.async do |task|
				task.sleep(10)
			end
			
			subject.stop
			
			expect(task1).to be_stopped
			expect(task2).to be_stopped
		end
		
		it "can stop several tasks when waiting on barrier" do
			task1 = subject.async do |task|
				task.sleep(10)
			end
			
			task2 = subject.async do |task|
				task.sleep(10)
			end
			
			task3 = reactor.async do
				subject.wait
			end
			
			subject.stop
			
			task1.wait
			task2.wait
			
			expect(task1).to be_stopped
			expect(task2).to be_stopped
			
			task3.wait
		end
		
		it "several tasks can wait on the same barrier" do
			task1 = subject.async do |task|
				task.sleep(10)
			end
			
			task2 = reactor.async do |task|
				subject.wait
			end
			
			task3 = reactor.async do
				subject.wait
			end
			
			subject.stop
			
			task1.wait
			
			expect(task1).to be_stopped
			
			task2.wait
			task3.wait
		end
	end
	
	context 'with semaphore' do
		let(:capacity) {2}
		let(:semaphore) {Async::Semaphore.new(capacity)}
		let(:repeats) {capacity * 2}
		
		it 'should execute several tasks and wait using a barrier' do
			repeats.times do
				subject.async(parent: semaphore) do |task|
					task.sleep 0.1
				end
			end
			
			expect(subject.size).to be == repeats
			subject.wait
		end
	end
	
	it_behaves_like 'chainable async'
end
