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

require 'async/rspec'
require 'async/condition'

require_relative 'condition_examples'

RSpec.describe Async::Condition, timeout: 1000 do
	include_context Async::RSpec::Reactor
	
	it 'should continue after condition is signalled' do
		task = reactor.async do
			subject.wait
		end
		
		expect(task.status).to be :running
		
		# This will cause the task to exit:
		subject.signal
		
		expect(task.status).to be :complete
	end
	
	it 'can stop nested task' do
		producer = nil
		
		consumer = reactor.async do |task|
			condition = Async::Condition.new
			
			producer = task.async do |subtask|
				subtask.yield
				condition.signal
				subtask.sleep(10)
			end
			
			condition.wait
			expect do
				producer.stop
			end.to_not raise_error
		end
		
		consumer.wait
		producer.wait
		
		expect(producer.status).to be :stopped
		expect(consumer.status).to be :complete
	end
	
	it_behaves_like Async::Condition
end
