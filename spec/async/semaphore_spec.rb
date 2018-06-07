# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/semaphore'

require_relative 'condition_examples'

RSpec.describe Async::Semaphore do
	include_context Async::RSpec::Reactor
	
	context '#async' do
		let(:repeats) {40}
		let(:limit) {4}
		
		it 'should process work in batches' do
			semaphore = Async::Semaphore.new(limit)
			current, maximum = 0, 0
			
			result = repeats.times.map do |i|
				semaphore.async do |task|
					current += 1
					maximum = [current, maximum].max
					task.sleep(rand * 0.1)
					current -= 1
					
					i
				end
			end.collect(&:result)
			
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
					task.sleep(0.1)
					order << i
				end
			end.collect(&:result)
			
			expect(order).to be == [0, 0, 1, 1, 2, 2]
		end
		
		it 'allows tasks to execute concurrently' do
			semaphore = Async::Semaphore.new(3)
			order = []
			
			3.times.map do |i|
				semaphore.async do |task|
					order << i
					task.sleep(0.1)
					order << i
				end
			end.collect(&:result)
			
			expect(order).to be == [0, 1, 2, 0, 1, 2]
		end
	end
	
	context '#count' do
		it 'should count number of current acquisitions' do
			expect(subject.count).to be == 0
			
			subject.acquire do
				expect(subject.count).to be == 1
			end
		end
	end
	
	context '#limit' do
		it 'should have a default limit' do
			expect(subject.limit).to be == 1
		end
	end
	
	context '#empty?' do
		it 'should be empty unless acquired' do
			expect(subject).to be_empty
			
			subject.acquire do
				expect(subject).to_not be_empty
			end
		end
	end
	
	context '#blocking?' do
		it 'will be blocking when acquired' do
			expect(subject).to_not be_blocking
			
			subject.acquire do
				expect(subject).to be_blocking
			end
		end
	end
	
	context '#acquire/#release' do
		it 'works when called without block' do
			subject.acquire
			
			expect(subject.count).to be == 1
			
			subject.release
			
			expect(subject.count).to be == 0
		end
	end
end
