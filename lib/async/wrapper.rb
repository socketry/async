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

module Async
	# Represents an asynchronous IO within a reactor.
	class Wrapper
		# @param io the native object to wrap.
		# @param reactor [Reactor] the reactor that is managing this wrapper.
		# @param bound [Boolean] whether the underlying socket will be closed if the wrapper is closed.
		def initialize(io, reactor)
			@io = io
			
			@reactor = reactor
			@monitor = nil
		end
		
		# The underlying native `io`.
		attr :io
		
		# The reactor this wrapper is associated with.
		attr :reactor
		
		# Wait for the io to become readable.
		def wait_readable
			wait_any(:r)
		end
		
		# Wait for the io to become writable.
		def wait_writable
			wait_any(:w)
		end
		
		# Wait fo the io to become either readable or writable.
		# @param interests [:r | :w | :rw] what events to wait for.
		def wait_any(interests = :rw)
			monitor(interests) do
				Task.yield
			end
		end
		
		# Close the monitor.
		def close
			@monitor.close if @monitor
			@monitor = nil
			
			@io.close if @io
		end
		
		private
		
		# Monitor the io for the given events
		# @param interests [:r | :w | :rw] what events to wait for.
		def monitor(interests)
			unless @monitor
				@monitor = @reactor.register(@io, interests)
			else
				@monitor.interests = interests
			end
			
			@monitor.value = Fiber.current
			
			yield
			
		ensure
			@monitor.value = nil if @monitor
		end
	end
end
