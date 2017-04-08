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

RSpec.describe Async::Reactor do
	it "can run asynchronously" do
		outer_fiber = Fiber.current
		inner_fiber = nil
		
		described_class.run do |task|
			task.sleep(0)
			inner_fiber = Fiber.current
		end
		
		expect(inner_fiber).to_not be nil
		expect(outer_fiber).to_not be == inner_fiber
	end
	
	it "can be stopped" do
		state = nil
		
		subject.async do |task|
			state = :started
			task.sleep(10)
			state = :stopped
		end
		
		subject.stop
		
		expect(state).to be == :started
	end
	
	it "can't return" do
		expect do
			Async::Reactor.run do |task|
				return
			end
		end.to raise_error(LocalJumpError)
	end
end
