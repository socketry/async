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

require 'benchmark'

RSpec.describe Async::Task do
	let(:reactor) {Async::Reactor.new}
	
	describe '#stop' do
		it "can be stopped" do
			state = nil
			
			task = reactor.async do |task|
				state = :started
				task.sleep(10)
				state = :finished
			end
			
			task.stop
			
			expect(state).to be == :started
		end
		
		it "should kill direct child" do
			parent_task = child_task = nil
			
			task = reactor.async do |task|
				parent_task = task
				reactor.async do |task|
					child_task = task
					task.sleep(10)
				end
				task.sleep(10)
			end
			
			expect(parent_task).to_not be_nil
			expect(child_task).to_not be_nil
			
			expect(parent_task.fiber).to be_alive
			expect(child_task.fiber).to be_alive
			
			parent_task.stop
			
			expect(parent_task.fiber).to_not be_alive
			expect(child_task.fiber).to_not be_alive
		end
	end
	
	describe '#sleep' do
		let(:duration) {0.01}
		
		it "can sleep for the requested duration" do
			state = nil
			
			task = reactor.async do |task|
				task.sleep(duration)
				state = :finished
			end
			
			time = Benchmark.realtime do
				reactor.run
			end
			
			expect(time).to be_within(50).percent_of(duration)
			expect(state).to be == :finished
		end
	end
	
	describe '#timeout' do
		it "will timeout if execution takes too long" do
			state = nil
			
			task = reactor.async do |task|
				task.timeout(0.01) do
					state = :started
					task.sleep(10)
					state = :finished
				end rescue nil
			end
			
			reactor.run
			
			expect(state).to be == :started
		end
		
		it "won't timeout if execution completes in time" do
			state = nil
			
			task = reactor.async do |task|
				state = :started
				task.timeout(0.01) do
					task.sleep(0.001)
					state = :finished
				end
			end
			
			reactor.run
			
			expect(state).to be == :finished
		end
	end
end
