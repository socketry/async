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

require 'fiber'
require 'forwardable'

require_relative 'node'

module Async
	class Interrupt < Exception
	end
	
	class Task < Node
		extend Forwardable
		
		def initialize(ios, reactor)
			if parent = Task.current?
				super(parent)
			else
				super(reactor)
			end
			
			@ios = Hash[
				ios.collect{|io| [io.fileno, reactor.wrap(io, self)]}
			]
			
			@reactor = reactor
			
			@result = nil
			
			@fiber = Fiber.new do
				set!
				
				begin
					complete yield(*@ios.values, self)
					# Async.logger.debug("Task #{self} completed normally.")
				rescue Interrupt
					# Async.logger.debug("Task #{self} interrupted: #{$!}")
				ensure
					consume
				end
			end
		end
		
		attr :ios
		
		attr :reactor
		def_delegators :@reactor, :timeout, :sleep
		
		attr :fiber
		def_delegators :@fiber, :alive?
		
		def run
			@fiber.resume
				
			return @fiber
		end
		
		def finished?
			!@fiber.alive?
		end
		
		def stop
			@children.each(&:stop)
			
			if @fiber.alive?
				exception = Interrupt.new("Stop right now!")
				@fiber.resume(exception)
			end
		end
		
		def with(io)
			wrapper = @reactor.wrap(io, self)
			
			yield wrapper
		ensure
			wrapper.close
			io.close
		end
		
		def bind(io)
			@ios[io.fileno] ||= reactor.wrap(io, self)
		end
		
		def register(io, interests)
			@reactor.register(io, interests)
		end
		
		def self.current
			Thread.current[:async_task] or raise RuntimeError, "No async task available!"
		end
		
		def self.current?
			Thread.current[:async_task]
		end
		
		def consume
			@ios.each_value(&:close)
			
			super
		end 
		
		def inspect
			"<#{self.class} 0x#{self.object_id.to_s(16)}>"
		end
		
		private
		
		def complete(result)
			@result = result
		end
		
		def set!
			# This is actually fiber-local:
			Thread.current[:async_task] = self
		end
	end
end
