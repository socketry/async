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
			
			expect(finished).to be < repeats
			
			duration = Async::Clock.measure{subject.wait}
			
			expect(duration).to be < (delay * 2)
			expect(finished).to be == repeats
		end
	end
end
