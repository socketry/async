# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/queue'

require_relative 'condition_examples'

RSpec.shared_context Async::Queue do
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
		Async do |consumer|
			10.times do
				subject.dequeue
				total_dequeued += 1

				expect(total_resumed).to be == total_dequeued
			end
		end
	end
end
