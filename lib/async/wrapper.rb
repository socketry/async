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
		def self.[] instance
			self
		end
		
		def initialize(io, task)
			@io = io
			@task = task
			@monitor = nil
		end
		
		attr :io
		attr :task
		
		def monitor(interests)
			unless @monitor
				@monitor = @task.register(@io, interests)
			else
				@monitor.interests = interests
			end
			
			@monitor.value = Fiber.current
			
			yield
			
		ensure
			@monitor.value = nil if @monitor
		end
		
		def wait_readable
			wait_any(:r)
		end
		
		def wait_writable
			wait_any(:w)
		end
		
		def wait_any(interests = :rw)
			monitor(interests) do
				# Async.logger.debug "Fiber #{Fiber.current} yielding..."
				result = Fiber.yield
				
				# Async.logger.debug "Fiber #{Fiber.current} resuming with result #{result}..."
				raise result if result.is_a? Exception
			end
		end
		
		def close
			@monitor.close if @monitor
			@monitor = nil
		end
	end
end
