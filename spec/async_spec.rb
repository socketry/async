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

require 'async'

RSpec.describe Async do
	describe '#Async' do
		it "can run an asynchronous task" do
			Async do |task|
				expect(task).to be_a Async::Task
			end
		end
	end
	
	describe '#Sync' do
		let(:value) {10}
		
		it "can run a synchronous task" do
			result = Sync do
				expect(Async::Task.current).to_not be nil
				
				next value
			end
			
			expect(result).to be == value
		end
		
		it "can run inside reactor" do
			Async do |task|
				result = Sync do
					expect(Async::Task.current).to be task
					
					next value
				end
				
				expect(result).to be == value
			end
		end
	end
	
	describe '.run' do
		it "can run an asynchronous task" do
			Async.run do |task|
				expect(task).to be_a Async::Task
			end
		end
	end
end
