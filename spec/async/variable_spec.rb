# frozen_string_literal: true

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

require 'async/variable'

RSpec.shared_examples_for Async::Variable do |value|
	it "can resolve the value to #{value.inspect}" do
		subject.resolve(value)
		is_expected.to be_resolved
	end
	
	it "can wait for the value to be resolved" do
		Async do
			expect(subject.wait).to be value
		end
		
		subject.resolve(value)
	end
	
	it "can't resolve it a 2nd time" do
		subject.resolve(value)
		expect do
			subject.resolve(value)
		end.to raise_error(FrozenError)
	end
end

RSpec.describe Async::Variable do
	include_context Async::RSpec::Reactor
	
	it_behaves_like Async::Variable, true
	it_behaves_like Async::Variable, false
	it_behaves_like Async::Variable, nil
	it_behaves_like Async::Variable, Object.new
end
