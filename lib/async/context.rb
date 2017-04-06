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

module Async
	class Interrupt < Exception
	end
	
	class Context
		extend Forwardable
		
		def initialize(ios, reactor, &block)
			@ios = ios.collect{|io| reactor.wrap(io, self)}
			@reactor = reactor
			
			@fiber = Fiber.new do
				set!
				
				begin
					yield(*@ios, self)
				rescue Interrupt
					Async.logger.debug("Context #{self} interrupted: #{$!}")
				ensure
					close
				end
			end
		end
		
		def_delegators :@reactor, :timeout, :sleep
		
		def run
			@fiber.resume
				
			return @fiber
		end
		
		def stop!
			if @fiber.alive?
				exception = Interrupt.new("Stop right now!")
				@fiber.resume(exception)
			end
		end
		
		attr :ios
		attr :reactor
		
		def with(io)
			wrapper = @reactor.wrap(io, self)
			
			yield wrapper
		ensure
			wrapper.close
			io.close
		end
		
		def register(io, interests)
			@reactor.register(io, interests)
		end
		
		def resolve(name)
			warn "Name resolution is not implemented for #{name}"
			
			return name
		end
		
		def self.get!
			Thread.current[:async_context] or raise RuntimeError, "No async context available!"
		end
		
		def self.reactor!
			get!.reactor
		end
		
		private
		
		def close
			@ios.each(&:close)
		end
		
		def set!
			# This is actually fiber-local:
			Thread.current[:async_context] = self
		end
	end
end
