# Copyright, 2018, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'monitor'
require_relative '../logger'

require 'nio'

module Async
	module Debug
		class Selector
			def initialize(selector = NIO::Selector.new)
				@selector = selector
				@monitors = {}
			end
			
			def register(object, interests)
				Async.logger.debug(self) {"Registering #{object.inspect} for #{interests}."}
				
				unless io = ::IO.try_convert(object)
					raise RuntimeError, "Could not convert #{io} into IO!"
				end
				
				if monitor = @monitors[io.fileno]
					raise RuntimeError, "Trying to register monitor for #{object.inspect} but it was already registered: #{monitor.inspect}!"
				end
				
				monitor = Monitor.new(@selector.register(object, interests), self)
				
				@monitors[io.fileno] = monitor
				
				return monitor
			end
			
			def deregister(object)
				Async.logger.debug(self) {"Deregistering #{object.inspect}."}
				
				unless io = ::IO.try_convert(object)
					raise RuntimeError, "Could not convert #{io} into IO!"
				end
				
				unless @monitors.delete(io.fileno)
					raise RuntimeError, "Trying to remove monitor for #{io.inspect} but it was not registered!"
				end
			end
			
			def wakeup
				@selector.wakeup
			end
			
			def close
				if @monitors.any?
					raise RuntimeError, "Trying to close selector with active monitors: #{@monitors.values.inspect}!"
				end
			ensure
				@selector.close
			end
			
			def select(*args)
				@selector.select(*args)
			end
		end
	end
end
