# frozen_string_literal: true

# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'async/barrier'
require 'async/clock'
require 'async/rspec'
require 'async/semaphore'

require_relative 'chainable_async_examples'

RSpec.describe Async::Barrier do
	include_context Async::RSpec::Reactor
	
	context '#async' do
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
	
	context '#wait' do
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
