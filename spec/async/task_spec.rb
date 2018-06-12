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
	
	describe '#run' do
		it "can't be invoked twice" do
			task = reactor.async do |task|
			end
			
			expect{task.run}.to raise_error(RuntimeError, /already running/)
		end
	end
	
	describe '#async' do
		it "can start child async tasks" do
			child = nil
			
			parent = reactor.async do |task|
				child = task.async do
					task.sleep(1)
				end
			end
			
			expect(parent).to_not be_nil
			expect(child).to_not be_nil
			expect(child.parent).to be parent
		end
		
		it "can pass in arguments" do
			reactor.async do |task|
				task.async(:arg) do |task, arg|
					expect(arg).to be == :arg
				end.wait
			end.wait
		end
	end
	
	describe '#yield' do
		it "can yield back to reactor" do
			state = nil
			
			task = reactor.async do |task|
				state = :started
				task.yield
				state = :finished
			end
			
			reactor.run
			
			expect(state).to be == :finished
		end
	end
	
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
		
		it "should not remove running task" do
			top_task = middle_task = bottom_task = nil
			
			top_task = reactor.async do |task|
				middle_task = reactor.async do |task|
					bottom_task = reactor.async do |task|
						task.sleep(10)
					end
					task.sleep(10)
				end
				task.sleep(10)
			end
			
			bottom_task.stop
			expect(top_task.children).to include(middle_task)
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
			
			# This is too unstable on travis.
			# expect(time).to be_within(50).percent_of(duration)
			expect(time).to be >= duration
			expect(state).to be == :finished
		end
	end
	
	describe '#timeout' do
		it "will timeout if execution takes too long" do
			state = nil
			
			task = reactor.async do |task|
				begin
					task.timeout(0.01) do
						state = :started
						task.sleep(10)
						state = :finished
					end
				rescue Async::TimeoutError
					state = :timeout
				end
			end
			
			reactor.run
			
			expect(state).to be == :timeout
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
	
	describe '#wait' do
		it "will wait on another task to complete" do
			result = nil
			
			apples_task = reactor.async do |task|
				task.sleep(0.1)
				
				:apples
			end
			
			oranges_task = reactor.async do |task|
				task.sleep(0.01)
				
				:oranges
			end
			
			fruit_salad_task = reactor.async do |task|
				result = [apples_task.result, oranges_task.result]
			end
			
			reactor.run
			
			expect(result).to be == [:apples, :oranges]
		end
		
		it "will propagate exceptions" do
			error_task = nil
			
			error_task = reactor.async do |task|
				task.sleep(0.1)
				
				raise ArgumentError.new("It simply wasn't good enough")
			end
			
			innocent_task = reactor.async do |task|
				expect{error_task.result}.to raise_error(ArgumentError, /wasn't good enough/)
			end
			
			begin
				reactor.run
			rescue Exception
				retry
			end
			
			expect(error_task).to be_finished
			expect(innocent_task).to be_finished
		end
	end
	
	describe '#to_s' do
		it "should show running" do
			apples_task = reactor.async do |task|
				task.sleep(0.1)
			end
			
			expect(apples_task.to_s).to include "running"
		end
		
		it "should show complete" do
			apples_task = reactor.async do |task|
			end
			
			expect(apples_task.to_s).to include "complete"
		end
	end
end
