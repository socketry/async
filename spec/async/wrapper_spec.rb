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

require "async/rspec"
require "async/wrapper"

RSpec.describe Async::Wrapper do
	include_context Async::RSpec::Reactor
	
	let(:pipe) {IO.pipe}
	let(:input) {Async::Wrapper.new(pipe.last)}
	let(:output) {Async::Wrapper.new(pipe.first)}
	
	after(:each) do
		input.close unless input.closed?
		output.close unless output.closed?
	end
	
	describe '#wait_readable' do
		it "can wait to be readable" do
			reader = reactor.async do
				expect(output.wait_readable).to be_truthy
			end
			
			input.io.write('Hello World')
			reader.wait
		end
		
		it "can timeout if no event occurs" do
			expect do
				output.wait_readable(0.1)
			end.to raise_exception(Async::TimeoutError)
		end
		
		it "can wait for readability in sequential tasks" do
			reactor.async do
				input.wait_writable(1)
				input.io.write('Hello World')
			end
			
			2.times do
				reactor.async do
					expect(output.wait_readable(1)).to be_truthy
				end.wait
			end
		end
	end
	
	describe '#wait_writable' do
		it "can wait to be writable" do
			expect(input.wait_writable).to be_truthy
		end
		
		it "can be cancelled while waiting to be readable" do
			task = reactor.async do
				input.wait_readable
			end
			
			output.close
			
			expect do
				task.wait
			end.to raise_exception(IOError)
		end
	end
	
	describe '#wait_priority' do
		let(:pipe) {::Socket.pair(:UNIX, :STREAM)}
		
		it "can invoke wait_priority on the underlying io" do
			expect(output.io).to receive(:wait_priority).and_return(true)
			output.wait_priority
		end
		
		it "can wait for out of band data" do
			begin
				# I've tested this successfully on Linux but it fails on Darwin.
				input.io.send('!', Socket::MSG_OOB)
			rescue => error
				skip error.message
			end
			
			reader = reactor.async do
				expect(output.wait_priority).to be_truthy
			end
			
			reader.wait
		end
	end
	
	describe "#wait_any" do
		it "can wait for any events" do
			reactor.async do
				input.wait_any(1)
				input.io.write('Hello World')
			end
			
			expect(output.wait_readable(1)).to be_truthy
		end
		
		it "can wait for readability in one task and writability in another" do
			reactor.async do
				expect do
					input.wait_readable(1)
				end.to raise_exception(IOError)
			end
			
			reactor.async do
				input.wait_writable
				
				input.close
				output.close
			end.wait
		end
	end
	
	describe '#reactor=' do
		it 'can assign a wrapper to a reactor' do
			input.reactor = reactor
			
			expect(input.reactor).to be == reactor
		end
	end
	
	describe '#dup' do
		let(:dup) {input.dup}
		
		it 'dups the underlying io' do
			expect(dup.io).to_not eq input.io
			
			dup.close
			
			expect(input).to_not be_closed
		end
	end
	
	describe '#close' do
		it "can't wait on closed wrapper" do
			input.close
			output.close
			
			expect do
				output.wait_readable
			end.to raise_exception(IOError, /closed stream/)
		end
	end
end
