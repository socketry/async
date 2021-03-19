# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'clock'

module Async
	class Scheduler
		if Fiber.respond_to?(:set_scheduler)
			def self.supported?
				true
			end
		else
			def self.supported?
				false
			end
		end
		
		def initialize(reactor)
			@reactor = reactor
		end
		
		attr :wrappers
		
		def set!
			Fiber.set_scheduler(self)
		end
		
		def clear!
			Fiber.set_scheduler(nil)
		end
		
		private def from_io(io)
			Wrapper.new(io, @reactor)
		end
		
		def io_wait(io, events, timeout = nil)
			wrapper = from_io(io)
			
			if events == ::IO::READABLE
				if wrapper.wait_readable(timeout)
					return ::IO::READABLE
				end
			elsif events == ::IO::WRITABLE
				if wrapper.wait_writable(timeout)
					return ::IO::WRITABLE
				end
			else
				if wrapper.wait_any(timeout)
					return events
				end
			end
			
			return false
		rescue TimeoutError
			return nil
		ensure
			wrapper&.reactor = nil
		end
		
		# Wait for the specified process ID to exit.
		# @parameter pid [Integer] The process ID to wait for.
		# @parameter flags [Integer] A bit-mask of flags suitable for `Process::Status.wait`.
		# @returns [Process::Status] A process status instance.
		def process_wait(pid, flags)
			Thread.new do
				::Process::Status.wait(pid, flags)
			end.value
		end
		
		def kernel_sleep(duration)
			self.block(nil, duration)
		end
		
		def block(blocker, timeout)
			@reactor.block(blocker, timeout)
		end
		
		def unblock(blocker, fiber)
			@reactor.unblock(blocker, fiber)
		end
		
		def close
		end
		
		def fiber(&block)
			task = Task.new(@reactor, &block)
			
			fiber = task.fiber
			
			task.run
			
			return fiber
		end
	end
end
