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

require_relative 'klass'

module Async
	module Wrap
		# Represents an asynchronous IO within a reactor.
		class IO
			extend Forwardable
			
			def initialize(io, context)
				@io = io
				@context = context
				@monitor = nil
			end
			
			def self.wrap_blocking_method(new_name, method_name)
				# puts "#{self}\##{$1} -> #{method_name}"
				define_method(new_name) do |*args|
					while true
						begin
							result = @io.__send__(method_name, *args)
							
							case result
							when :wait_readable
								wait_readable
							when :wait_writable
								wait_writable
							else
								return result
							end
						rescue ::IO::WaitReadable
							wait_readable
							retry
						rescue ::IO::WaitWritable
							wait_writable
							retry
						end
					end
				end
			end
			
			def self.wraps(klass, *additional_methods)
				Wrap[klass] = self
				
				klass.instance_methods(false).grep(/(.*)_nonblock/) do |method_name|
					wrap_blocking_method($1, method_name)
				end
				
				additional_methods.each do |method_name|
					wrap_blocking_method(method_name, method_name)
				end
			end
			
			wraps ::IO
			
			attr :context
			
			def monitor(interests)
				unless @monitor
					@monitor = @context.register(@io, interests)
				else
					@monitor.interests = interests
				end
				
				@monitor.value = Fiber.current
				
				yield
				
			ensure
				@monitor.value = nil
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
			
			def method_missing(name, *args, &block)
				@io.__send__(name, *args, &block)
			end
			
			def close
				@monitor.close if @monitor
				@monitor = nil
			end
		end
	end
end
