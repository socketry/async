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

require 'nio'

module Async
	# Represents an asynchronous IO within a reactor.
	class Wrapper
		class Cancelled < StandardError
			class From
				def initialize
					@backtrace = caller[5..-1]
				end
				
				attr :backtrace
				
				def cause
					nil
				end
				
				def message
					"Cancelled"
				end
			end
			
			def initialize
				super "The operation has been cancelled!"
				
				@cause = From.new
			end
			
			attr :cause
		end
		
		# wait_readable, wait_writable and wait_any are not re-entrant, and will raise this failure.
		class WaitError < StandardError
			def initialize
				super "A fiber is already waiting!"
			end
		end
		
		# @param io the native object to wrap.
		# @param reactor [Reactor] the reactor that is managing this wrapper, or not specified, it's looked up by way of {Task.current}.
		def initialize(io, reactor = nil)
			@io = io
			
			@reactor = reactor
			@monitor = nil
			
			@readable = nil
			@writable = nil
			@any = nil
		end
		
		def dup
			self.class.new(@io.dup, @reactor)
		end
		
		def resume(*arguments)
			# It's possible that the monitor was closed before calling resume.
			return unless @monitor
			
			readiness = @monitor.readiness
			
			if @readable and (readiness == :r or readiness == :rw)
				@readable.resume(*arguments)
			end
			
			if @writable and (readiness == :w or readiness == :rw)
				@writable.resume(*arguments)
			end
			
			if @any
				@any.resume(*arguments)
			end
		end
		
		# The underlying native `io`.
		attr :io
		
		# The reactor this wrapper is associated with, if any.
		attr :reactor
		
		# The monitor for this wrapper, if any.
		attr :monitor
		
		# Bind this wrapper to a different reactor. Assign nil to convert to an unbound wrapper (can be used from any reactor/task but with slightly increased overhead.)
		# Binding to a reactor is purely a performance consideration. Generally, I don't like APIs that exist only due to optimisations. This is borderline, so consider this functionality semi-private.
		def reactor= reactor
			return if @reactor.equal?(reactor)
			
			cancel_monitor
			
			@reactor = reactor
		end
		
		# Wait for the io to become readable.
		def wait_readable(timeout = nil)
			raise WaitError if @readable
			
			self.reactor = Task.current.reactor
			
			begin
				@readable = Fiber.current
				wait_for(timeout)
			ensure
				@readable = nil
				@monitor.interests = interests if @monitor
			end
		end
		
		# Wait for the io to become writable.
		def wait_writable(timeout = nil)
			raise WaitError if @writable
			
			self.reactor = Task.current.reactor
			
			begin
				@writable = Fiber.current
				wait_for(timeout)
			ensure
				@writable = nil
				@monitor.interests = interests if @monitor
			end
		end
		
		# Wait fo the io to become either readable or writable.
		# @param duration [Float] timeout after the given duration if not `nil`.
		def wait_any(timeout = nil)
			raise WaitError if @any
			
			self.reactor = Task.current.reactor
			
			begin
				@any = Fiber.current
				wait_for(timeout)
			ensure
				@any = nil
				@monitor.interests = interests if @monitor
			end
		end
		
		# Close the io and monitor.
		def close
			cancel_monitor
			
			@io.close
		end
		
		def closed?
			@io.closed?
		end
		
		private
		
		# What an abomination.
		def interests
			if @any
				return :rw
			elsif @readable
				if @writable
					return :rw
				else
					return :r
				end
			elsif @writable
				return :w
			end
			
			return nil
		end
		
		def cancel_monitor
			if @readable
				readable = @readable
				@readable = nil
				
				readable.resume(Cancelled.new)
			end
			
			if @writable
				writable = @writable
				@writable = nil
				
				writable.resume(Cancelled.new)
			end
			
			if @any
				any = @any
				@any = nil
				
				any.resume(Cancelled.new)
			end
			
			if @monitor
				@monitor.close
				@monitor = nil
			end
		end
		
		def wait_for(timeout)
			if @monitor
				@monitor.interests = interests
			else
				@monitor = @reactor.register(@io, interests, self)
			end
			
			# If the user requested an explicit timeout for this operation:
			if timeout
				@reactor.with_timeout(timeout) do
					Task.yield
				end
			else
				Task.yield
			end
			
			return true
		end
	end
end
