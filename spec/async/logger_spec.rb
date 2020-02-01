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

require 'async'
require 'async/logger'
require 'console/capture'

RSpec.describe 'Async.logger' do
	let(:name) {"nested"}
	let(:message) {"Talk is cheap. Show me the code."}
	
	let(:capture) {Console::Capture.new}
	let(:logger) {Console::Logger.new(capture, name: name)}
	
	it "can use nested logger" do
		Async(logger: logger) do |task|
			expect(task.logger).to be == logger
			logger.warn message
		end.wait
		
		expect(capture.events.last).to include({
			severity: :warn,
			name: name,
			subject: message,
		})
	end
	
	it "can change nested logger" do
		Async do |parent|
			parent.async(logger: logger) do |task|
				expect(task.logger).to be == logger
				expect(Async.logger).to be == logger
			end.wait
		end.wait
	end
	
	it "can use parent logger" do
		Async(logger: logger) do |parent|
			child = parent.async{|task| task.yield}
			
			expect(parent.logger).to be == logger
			expect(child.logger).to be == logger
			expect(Async.logger).to be == logger
		end.wait
	end
end
