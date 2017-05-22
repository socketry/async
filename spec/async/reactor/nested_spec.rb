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
	describe '::run (in existing reactor)' do
		include_context Async::RSpec::Reactor
		
		it "should nest reactor" do
			outer_reactor = Async::Task.current.reactor
			inner_reactor = nil
			
			task = described_class.run do |task|
				inner_reactor = task.reactor
			end 
			
			expect(outer_reactor).to be_kind_of(described_class)
			expect(outer_reactor).to be_eql(inner_reactor)
		end
	end
	
	describe '::run' do
		it "should nest reactor" do
			expect(Async::Task.current?).to be_nil
			inner_reactor = nil
			
			task = described_class.run do |task|
				inner_reactor = task.reactor
			end 
			
			expect(inner_reactor).to be_kind_of(described_class)
		end
	end
end
