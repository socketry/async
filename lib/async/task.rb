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
require_relative 'condition'

module Async
	class Interrupt < Exception
	end
	
	class Task < Node
		extend Forwardable
		
		def self.yield
			if block_given?
				result = yield
			else
				result = Fiber.yield
			end
			
			if result.is_a? Exception
				raise result
			else
				return result
			end
		end
		
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
			
			@status = :running
			@result = nil
			
			@condition = nil
			
			@fiber = Fiber.new do
				set!
				
				begin
					@result = yield(*@ios.values, self)
					@status = :complete
					# Async.logger.debug("Task #{self} completed normally.")
				rescue Interrupt
					@status = :interrupted
					# Async.logger.debug("Task #{self} interrupted: #{$!}")
				rescue Exception => error
					@result = error
					@status = :failed
					# Async.logger.debug("Task #{self} failed: #{$!}")
					raise
				ensure
					# Async.logger.debug("Task #{self} closing: #{$!}")
					close
				end
			end
		end
		
		def to_s
			"#{super}[#{@status}]"
		end
		
		attr :ios
		
		attr :reactor
		def_delegators :@reactor, :timeout, :sleep
		
		attr :fiber
		def_delegators :@fiber, :alive?
		
		attr :status
		attr :result
		
		def run
			@fiber.resume
		end
		
		def result
			raise RuntimeError.new("Cannot wait on own fiber") if Fiber.current.equal?(@fiber)
			
			if running?
				@condition ||= Condition.new
				@condition.wait
			else
				Task.yield {@result}
			end
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
		
		def running?
			@status == :running
		end
		
		# Whether we can remove this node from the reactor graph.
		def finished?
			super && @status != :running
		end
		
		def close
			@ios.each_value(&:close)
			@ios = []
			
			consume
			
			if @condition
				@condition.signal(@result)
			end
		end
		
		private
		
		def set!
			# This is actually fiber-local:
			Thread.current[:async_task] = self
		end
	end
end
