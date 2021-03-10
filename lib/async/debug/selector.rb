# frozen_string_literal: true

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
require 'set'

module Async
	module Debug
		class LeakError < RuntimeError
			def initialize(monitors)
				super "Trying to close selector with active monitors: #{monitors.inspect}! This may cause your socket or file descriptor to leak."
			end
		end

		class Selector
			def initialize(selector = NIO::Selector.new)
				@selector = selector
				@monitors = Set.new
			end
			
			def register(object, interests)
				Async.logger.debug(self) {"Registering #{object.inspect} for #{interests}."}
				
				unless io = ::IO.try_convert(object)
					raise RuntimeError, "Could not convert #{io} into IO!"
				end
				
				monitor = Monitor.new(@selector.register(object, interests), self)
				
				@monitors.add(monitor)
				
				return monitor
			end
			
			def deregister(monitor)
				Async.logger.debug(self) {"Deregistering #{monitor.inspect}."}
				
				unless @monitors.delete?(monitor)
					raise RuntimeError, "Trying to remove monitor for #{monitor.inspect} but it was not registered!"
				end
			end
			
			def wakeup
				@selector.wakeup
			end
			
			def close
				if @monitors.any?
					raise LeakError, @monitors
				end
			ensure
				@selector.close
			end
			
			def select(*arguments)
				@selector.select(*arguments)
			end
		end
	end
end
