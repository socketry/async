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

module Async
	# Represents an asynchronous IO within a reactor.
	class Wrapper
		class Cancelled < StandardError
		end
		
		# @param io the native object to wrap.
		# @param reactor [Reactor] the reactor that is managing this wrapper, or not specified, it's looked up by way of {Task.current}.
		def initialize(io, reactor = nil)
			@io = io
			@reactor = reactor
			
			@timeout = nil
		end
		
		attr_accessor :reactor
		
		def dup
			self.class.new(@io.dup)
		end
		
		# The underlying native `io`.
		attr :io
		
		# Wait for the io to become readable.
		def wait_readable(timeout = @timeout)
			@io.to_io.wait_readable(timeout) or raise TimeoutError
		end
		
		# Wait for the io to become writable.
		def wait_priority(timeout = @timeout)
			@io.to_io.wait_priority(timeout) or raise TimeoutError
		end
		
		# Wait for the io to become writable.
		def wait_writable(timeout = @timeout)
			@io.to_io.wait_writable(timeout) or raise TimeoutError
		end
		
		# Wait fo the io to become either readable or writable.
		# @param duration [Float] timeout after the given duration if not `nil`.
		def wait_any(timeout = @timeout)
			@io.wait_any(timeout) or raise TimeoutError
		end
		
		# Close the io and monitor.
		def close
			@io.close
		end
		
		def closed?
			@io.closed?
		end
	end
end
