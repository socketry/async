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

require_relative 'reactor'
require 'thread'

module Async
	# Manages a reactor within one or more threads.
	module Container
		def self.new(klass: ThreadContainer, **options, &block)
			klass.new(**options, &block)
		end
	end
	
	class ThreadContainer
		def initialize(concurrency: 1, &block)
			@reactors = concurrency.times.collect do
				Async::Reactor.new
			end
			
			@threads = @reactors.collect do |reactor|
				Thread.new do
					reactor.run(&block)
				end
			end
		end
		
		def stop
			@reactors.each(&:stop)
			@threads.each(&:join)
		end
	end
	
	class ProcessContainer
		def initialize(concurrency: 1, &block)
			@pids = concurrency.times.collect do
				fork do
					Async::Reactor.run(&block)
				end
			end
		end
		
		def stop
			@pids.each do |pid|
				Process.kill(:INT, pid) rescue nil
				Process.wait(pid)
			end
		end
	end
end
