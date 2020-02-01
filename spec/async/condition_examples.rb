# frozen_string_literal: true

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

RSpec.shared_examples Async::Condition do
	it 'can signal waiting task' do
		state = nil
		
		reactor.async do
			state = :waiting
			subject.wait
			state = :resumed
		end
		
		expect(state).to be == :waiting
		
		subject.signal
		
		reactor.yield
		
		expect(state).to be == :resumed
	end
	
	it 'should be able to signal stopped task' do
		expect(subject.empty?).to be_truthy
		
		task = reactor.async do
			subject.wait
		end
		
		expect(subject.empty?).to be_falsey
		
		task.stop
		
		subject.signal
	end
	
	it 'resumes tasks in order' do
		order = []
		
		5.times do |i|
			task = reactor.async do
				subject.wait
				order << i
			end
		end
		
		subject.signal
		
		reactor.yield
		
		expect(order).to be == [0, 1, 2, 3, 4]
	end
	
	context "with timeout" do
		before do
			@state = nil
		end
		
		let!(:task) do
			reactor.async do |task|
				task.with_timeout(0.1) do
					begin
						@state = :waiting
						subject.wait
						@state = :signalled
					rescue Async::TimeoutError
						@state = :timeout
					end
				end
			end
		end
		
		it 'can timeout while waiting' do
			task.wait
			
			expect(@state).to be == :timeout
		end
		
		it 'can signal while waiting' do
			subject.signal
			task.wait
			
			expect(@state).to be == :signalled
		end
	end
end
