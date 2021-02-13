# Copyright, 2021, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require 'async/scheduler'

RSpec.describe Async::Scheduler, if: Async::Scheduler.supported? do
	include_context Async::RSpec::Reactor
	
	describe ::Thread do
		it "can wait for value" do
			value = Thread.new do
				sleep(0)
				:value
			end.value
			
			expect(value).to be == :value
		end
		
		it "can propagate exception" do
			thread = nil
			
			task = Async do
				begin
					thread = Thread.new do
						sleep
					end
					
					thread.join
				ensure
					thread.kill
				end
			end
			
			task.stop
			
			sleep(0)
			expect(thread).to_not be_alive
		end
	end
end
