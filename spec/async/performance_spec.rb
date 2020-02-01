# frozen_string_literal: true

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

require 'benchmark/ips'
require 'async'

RSpec.describe Async::Wrapper do
	let(:pipe) {IO.pipe}
	
	after do
		pipe.each(&:close)
	end
	
	let(:input) {described_class.new(pipe.first)}
	let(:output) {described_class.new(pipe.last)}
	
	it "should be fast to wait until readable" do
		Benchmark.ips do |x|
			x.report('Wrapper#wait_readable') do |repeats|
				Async do |task|
					input = Async::Wrapper.new(pipe.first, task.reactor)
					output = pipe.last
					
					repeats.times do
						output.write(".")
						input.wait_readable
						input.io.read(1)
					end
					
					input.reactor = nil
				end
			end
			
			x.report('Reactor#register') do |repeats|
				Async do |task|
					input = pipe.first
					monitor = task.reactor.register(input, :r)
					output = pipe.last
					
					repeats.times do
						output.write(".")
						Async::Task.yield
						input.read(1)
					end
					
					monitor.close
				end
			end
			
			x.compare!
		end
	end
end
