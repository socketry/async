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
require 'io/nonblock'

RSpec.describe Async::Scheduler, if: Async::Scheduler.supported? do
	include_context Async::RSpec::Reactor
	
	describe ::IO do
		it "can wait with timeout" do
			expect(reactor).to receive(:io_wait).and_call_original
			
			s1, s2 = Socket.pair :UNIX, :STREAM, 0
			
			result = s1.wait_readable(0)
			
			expect(result).to be_nil
		ensure
			s1.close
			s2.close
		end
		
		it "can read a single character" do
			s1, s2 = Socket.pair :UNIX, :STREAM, 0
			
			child = reactor.async do
				c = s2.getc
				expect(c).to be == 'a'
			end
			
			s1.putc('a')
			
			child.wait
		end
		
		it "can perform blocking read" do
			s1, s2 = Socket.pair :UNIX, :STREAM, 0
			
			s1.nonblock = false
			s2.nonblock = false
			
			child = reactor.async do
				expect(s2.read(1)).to be == 'a'
				expect(s2.read(1)).to be == nil
			end
			
			sleep(0.1)
			s1.write('a')
			sleep(0.1)
			s1.close
			
			child.wait
		end
	end
end
