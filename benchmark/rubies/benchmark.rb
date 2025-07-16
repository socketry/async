#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "socket"
require "fiber"

puts
puts RUBY_DESCRIPTION

if RUBY_VERSION < "2.0"
	class String
		def b
			self
		end
	end
end

# TODO: make these much larger, see if we're effectively batching
# even if we don't mean to...
QUERY_TEXT = "STATUS".freeze
RESPONSE_TEXT = "OK".freeze

NUM_WORKERS = (ARGV[0] || 10_000).to_i
NUM_REQUESTS = (ARGV[1] || 100).to_i

# Fiber reactor code taken from
# https://www.codeotaku.com/journal/2018-11/fibers-are-the-right-solution/index
class Reactor
	def initialize
		@readable = {}
		@writable = {}
	end
	
	def run
		while @readable.any? or @writable.any?
			readable, writable = IO.select(@readable.keys, @writable.keys, [])
			
			readable.each do |io|
				@readable[io].resume
			end
			
			writable.each do |io|
				@writable[io].resume
			end
		end
	end
	
	def wait_readable(io)
		@readable[io] = Fiber.current
		Fiber.yield
		@readable.delete(io)
	end
	
	def wait_writable(io)
		@writable[io] = Fiber.current
		Fiber.yield
		@writable.delete(io)
	end
end

class Wrapper
	def initialize(io, reactor)
		@io = io
		@reactor = reactor
	end
	
	if RUBY_VERSION >= "2.3"
		def read_nonblock(length, buffer)
			while true
				case result = @io.read_nonblock(length, buffer, exception: false)
				when :wait_readable
					@reactor.wait_readable(@io)
				when :wait_writable
					@reactor.wait_writable(@io)
				else
					return result
				end
			end
			
		end
		
		def write_nonblock(buffer)
			while true
				case result = @io.write_nonblock(buffer, exception: false)
				when :wait_readable
					@reactor.wait_readable(@io)
				when :wait_writable
					@reactor.wait_writable(@io)
				else
					return result
				end
			end
		end
	else
		def read_nonblock(length, buffer)
			while true
				begin
					return @io.read_nonblock(length, buffer)
				rescue IO::WaitReadable
					@reactor.wait_readable(@io)
				rescue IO::WaitWritable
					@reactor.wait_writable(@io)
				end
			end
		end
		
		def write_nonblock(buffer)
			while true
				begin
					return @io.write_nonblock(buffer)
				rescue IO::WaitReadable
					@reactor.wait_readable(@io)
				rescue IO::WaitWritable
					@reactor.wait_writable(@io)
				end
			end
		end
	end
	
	def read(length, buffer = nil)
		if buffer
			buffer.clear
		else
			buffer = String.new.b
		end
		
		result = self.read_nonblock(length - buffer.bytesize, buffer)
		
		if result == length
			return result
		end
		
		chunk = String.new.b
		while chunk = self.read_nonblock(length - buffer.bytesize, chunk)
			buffer << chunk
			
			break if buffer.bytesize == length
		end
		
		return buffer
	end
	
	def write(buffer)
		remaining = buffer.dup
		
		while true
			result = self.write_nonblock(remaining)
			
			if result == remaining.bytesize
				return buffer.bytesize
			else
				remaining = remaining.byteslice(result, remaining.bytesize - result)
			end
		end
	end
end

reactor = Reactor.new

worker_read = []
worker_write = []

master_read = []
master_write = []

workers = []

# puts "Setting up pipes..."
NUM_WORKERS.times do |i|
	r, w = IO.pipe
	worker_read.push Wrapper.new(r, reactor)
	master_write.push Wrapper.new(w, reactor)
	
	r, w = IO.pipe
	worker_write.push Wrapper.new(w, reactor)
	master_read.push Wrapper.new(r, reactor)
end

# puts "Setting up fibers..."
NUM_WORKERS.times do |i|
	f = Fiber.new do
		# Worker code
		NUM_REQUESTS.times do |req_num|
			q = worker_read[i].read(QUERY_TEXT.size)
			if q != QUERY_TEXT
				raise "Fail! Expected #{QUERY_TEXT.inspect} but got #{q.inspect} on request #{req_num.inspect}!"
			end
			worker_write[i].write(RESPONSE_TEXT)
		end
	end
	workers.push f
end

workers.each {|f| f.resume}

master_fiber = Fiber.new do
	NUM_WORKERS.times do |worker_num|
		f = Fiber.new do
			NUM_REQUESTS.times do |req_num|
				master_write[worker_num].write(QUERY_TEXT)
				buffer = master_read[worker_num].read(RESPONSE_TEXT.size)
				if buffer != RESPONSE_TEXT
					raise "Error! Fiber no. #{worker_num} on req #{req_num} expected #{RESPONSE_TEXT.inspect} but got #{buf.inspect}!"
				end
			end
		end
		f.resume
	end
end

master_fiber.resume

# puts "Starting reactor..."
reactor.run

# puts "Done, finished all reactor Fibers!"

puts Process.times

# Exit
