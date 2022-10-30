# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.

require 'async/semaphore'
require 'async/barrier'
require 'sus/fixtures/async'

require 'chainable_async'
require 'timer_quantum'

describe Async::Semaphore do
	include Sus::Fixtures::Async::ReactorContext
	let(:semaphore) {subject.new}
	
	with '#async' do
		let(:repeats) {10}
		let(:limit) {4}
		
		it 'should process work in batches' do
			semaphore = Async::Semaphore.new(limit)
			current, maximum = 0, 0
			
			result = repeats.times.map do |i|
				semaphore.async do |task|
					current += 1
					maximum = [current, maximum].max
					task.sleep(rand * 0.01)
					current -= 1
					
					i
				end
			end.collect(&:wait)
			
			# Verify that the maximum number of concurrent tasks was the specificed limit:
			expect(maximum).to be == limit
			
			# Verify that the results were in the correct order:
			expect(result).to be == (0...repeats).to_a
		end
		
		it 'only allows one task at a time' do
			semaphore = Async::Semaphore.new(1)
			order = []
			
			3.times.map do |i|
				semaphore.async do |task|
					order << i
					task.sleep(0.01)
					order << i
				end
			end.collect(&:wait)
			
			expect(order).to be == [0, 0, 1, 1, 2, 2]
		end
		
		it 'allows tasks to execute concurrently' do
			semaphore = Async::Semaphore.new(3)
			order = []
			
			3.times.map do |i|
				semaphore.async do |task|
					order << i
					task.sleep(0.01)
					order << i
				end
			end.collect(&:wait)
			
			expect(order).to be == [0, 1, 2, 0, 1, 2]
		end
	end
	
	with '#waiting' do
		let(:semaphore) {Async::Semaphore.new(0)}
		
		it 'handles exceptions thrown while waiting' do
			expect do
				reactor.with_timeout(0.001) do
					semaphore.acquire do
					end
				end
			end.to raise_exception(Async::TimeoutError)
			
			expect(semaphore.waiting).to be(:empty?)
		end
	end
	
	with '#count' do
		it 'should count number of current acquisitions' do
			expect(semaphore.count).to be == 0
			
			semaphore.acquire do
				expect(semaphore.count).to be == 1
			end
		end
	end
	
	with '#limit' do
		it 'should have a default limit' do
			expect(semaphore.limit).to be == 1
		end
	end
	
	with '#empty?' do
		it 'should be empty unless acquired' do
			expect(semaphore).to be(:empty?)
			
			semaphore.acquire do
				expect(semaphore).not.to be(:empty?)
			end
		end
	end
	
	with '#blocking?' do
		it 'will be blocking when acquired' do
			expect(semaphore).not.to be(:blocking?)
			
			semaphore.acquire do
				expect(semaphore).to be(:blocking?)
			end
		end
	end
	
	with '#acquire/#release' do
		it 'works when called without block' do
			semaphore.acquire
			
			expect(semaphore.count).to be == 1
			
			semaphore.release
			
			expect(semaphore.count).to be == 0
		end
	end
	
	with 'barrier' do
		let(:capacity) {2}
		let(:barrier) {Async::Barrier.new}
		let(:repeats) {capacity * 2}
		
		it 'should execute several tasks and wait using a barrier' do
			repeats.times do
				semaphore.async(parent: barrier) do |task|
					task.sleep(0.01)
				end
			end
			
			expect(barrier.size).to be == repeats
			barrier.wait
		end
	end
	
	it_behaves_like ChainableAsync
end
