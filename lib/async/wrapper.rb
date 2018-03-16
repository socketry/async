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
		# @param io the native object to wrap.
		# @param reactor [Reactor] the reactor that is managing this wrapper, or not specified, it's looked up by way of {Task.current}.
		# @param bound [Boolean] whether the underlying socket will be closed if the wrapper is closed.
		def initialize(io, reactor = nil)
			@io = io
			
			@reactor = reactor
			@monitor = nil
		end
		
		# The underlying native `io`.
		attr :io
		
		# The reactor this wrapper is associated with, if any.
		attr :reactor
		
		# Bind this wrapper to a different reactor. Assign nil to convert to an unbound wrapper (can be used from any reactor/task but with slightly increased overhead.)
		# Binding to a reactor is purely a performance consideration. Generally, I don't like APIs that exist only due to optimisations. This is borderline, so consider this functionality semi-private.
		def reactor= reactor
			@monitor&.close
			
			@reactor = reactor
			@monitor = nil
		end
		
		# Wait for the io to become readable.
		def wait_readable(duration = nil)
			wait_any(:r, duration)
		end
		
		# Wait for the io to become writable.
		def wait_writable(duration = nil)
			wait_any(:w, duration)
		end
		
		# Wait fo the io to become either readable or writable.
		# @param interests [:r | :w | :rw] what events to wait for.
		# @param duration [Float] timeout after the given duration if not `nil`.
		def wait_any(interests = :rw, duration = nil)
			# There is value in caching this monitor - if you can reuse it, you will get about 2x the throughput, because you avoid calling Reactor#register and Monitor#close for every call. That being said, by caching it, you also introduce lifetime issues. I'm going to accept this overhead into the wrapper design because it's pretty convenient, but if you want faster IO, take a look at the performance spec which compares this method with a more direct alternative.
			if @reactor
				unless @monitor
					@monitor = @reactor.register(@io, interests)
				else
					@monitor.interests = interests
					@monitor.value = Fiber.current
				end
				
				begin
					wait_for(@reactor, @monitor, duration)
				ensure
					@monitor.remove_interest(@monitor.interests)
				end
			else
				reactor = Task.current.reactor
				monitor = reactor.register(@io, interests)
				
				begin
					wait_for(reactor, monitor, duration)
				ensure
					monitor.close
				end
			end
		end
		
		# Close the io and monitor.
		def close
			@monitor&.close
			
			@io.close
		end
		
		private
		
		def wait_for(reactor, monitor, duration)
			# If the user requested an explicit timeout for this operation:
			if duration
				reactor.timeout(duration) do
					Task.yield
				end
			else
				Task.yield
			end
			
			return true
		end
	end
end
