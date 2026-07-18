#!/usr/bin/env ruby
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

GC.disable

class FakeBody
	def each
		yield "Fake Body"
	end
end

object = FakeBody.new

class Stream
	def write(chunk)
	end
end

stream = Stream.new

proc = Proc.new do |stream|
	stream.write "Fake Body"
end

hash = Hash.new
10.times do |i|
	hash['fake-header-i'] = i
end

hijack_hash = hash.dup
hijack_hash['rack.hijack'] = proc

Benchmark.ips do |benchmark|
	benchmark.time = 1
	benchmark.warmup = 1
	
	benchmark.report("object") do |count|
		while count > 0
			if object.respond_to?(:call)
				object.call(stream)
			else
				object.each{|x| stream.write(x)}
			end
			
			count -= 1
		end
	end
	
	benchmark.report("proc") do |count|
		while count > 0
			if proc.respond_to?(:call)
				proc.call(stream)
			else
				object.each{|x| stream.write(x)}
			end
			
			count -= 1
		end
	end
	
	benchmark.report("hash") do |count|
		while count > 0
			if hijack = hash['rack.hijack']
				hijack.call(stream)
			else
				object.each{|x| stream.write(x)}
			end
			
			count -= 1
		end
	end
	
	benchmark.report("hijack-hash") do |count|
		while count > 0
			if hijack = hijack_hash['rack.hijack']
				hijack.call(stream)
			else
				object.each{|x| stream.write(x)}
			end
			
			count -= 1
		end
	end
	
	benchmark.compare!
end
