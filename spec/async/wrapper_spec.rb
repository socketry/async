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

require 'benchmark'

RSpec.describe Async::Wrapper do
	include_context Async::RSpec::Reactor
	
	let(:pipe) {IO.pipe}
	let(:input) {Async::Wrapper.new(pipe.last)}
	let(:output) {Async::Wrapper.new(pipe.first)}
	
	after(:each) do
		input.close unless input.closed?
		output.close unless output.closed?
		
		expect(input.monitor).to be_nil
		expect(output.monitor).to be_nil
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
			expect(output.wait_readable(0.1)).to be_falsey
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
		
		it "can be cancelled" do
			reactor.async do
				expect do
					output.wait_readable
				end.to raise_error(Async::Wrapper::Cancelled)
			end
			
			expect(output.monitor).to_not be_nil
		end
	end
	
	describe '#wait_writable' do
		it "can wait to be writable" do
			expect(input.wait_writable).to be_truthy
		end
		
		it "can be cancelled while waiting to be readable" do
			reactor.async do
				expect do
					input.wait_readable
				end.to raise_error(Async::Wrapper::Cancelled)
			end
			
			# This reproduces the race condition that can occur if two tasks are resumed in sequence.
			
			# Resume task 1 which closes IO:
			output.close
			
			# Resume task 2:
			expect do
				output.resume
			end.to_not raise_error
		end
		
		it "can be cancelled" do
			reactor.async do
				expect do
					input.wait_readable
				end.to raise_error(Async::Wrapper::Cancelled)
			end
			
			expect(input.monitor).to_not be_nil
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
				end.to raise_error(Async::Wrapper::Cancelled)
			end
			
			expect(input.monitor.interests).to be == :r
			
			reactor.async do
				input.wait_writable
				
				input.close
				output.close
			end.wait
		end
		
		it "fails if waiting on from multiple tasks" do
			input.reactor = reactor
			
			reactor.async do
				expect do
					input.wait_readable
				end.to raise_error(Async::Wrapper::Cancelled)
			end
			
			expect(input.monitor.interests).to be == :r
			
			reactor.async do
				expect do
					input.wait_readable
				end.to raise_error(Async::Wrapper::WaitError)
			end
		end
	end
	
	describe '#reactor=' do
		it 'can assign a wrapper to a reactor' do
			input.reactor = reactor
			
			expect(input.reactor).to be == reactor
		end
		
		it 'assigns current reactor when waiting for events' do
			input.wait_writable
			
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
		it "closes monitor when closing wrapper" do
			input.wait_writable
			expect(input.monitor).to_not be_nil
			input.close
			expect(input.monitor).to be_nil
		end
		
		it "can't wait on closed wrapper" do
			input.close
			output.close
			
			expect do
				output.wait_readable
			end.to raise_error(IOError, /closed stream/)
		end
	end
end
