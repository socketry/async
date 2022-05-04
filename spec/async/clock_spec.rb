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

require 'async/clock'

RSpec.describe Async::Clock do
	it "can measure durations" do
		duration = Async::Clock.measure do
			sleep 0.1
		end
		
		expect(duration).to be_within(0.01 * Q).of(0.1)
	end
	
	it "can get current offset" do
		expect(Async::Clock.now).to be_kind_of Float
	end
	
	it "can accumulate durations" do
		2.times do
			subject.start!
			sleep(0.1)
			subject.stop!
		end
		
		expect(subject.total).to be_within(0.02 * Q).of(0.2)
	end
	
	context 'with given total' do
		subject {described_class.new(1.5)}
		
		it{is_expected.to have_attributes(total: 1.5)}
	end
end
