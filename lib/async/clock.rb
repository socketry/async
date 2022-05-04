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

module Async
	# A convenient wrapper around the internal monotonic clock.
	# @public Since `stable-v1`.
	class Clock
		# Get the current elapsed monotonic time.
		def self.now
			::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
		end
		
		# Measure the execution of a block of code.
		# @yields {...} The block to execute.
		# @returns [Numeric] The total execution time.
		def self.measure
			start_time = self.now
			
			yield
			
			return self.now - start_time
		end
		
		# Start measuring elapsed time from now.
		# @returns [Clock]
		def self.start
			self.new.tap(&:start!)
		end
		
		# Create a new clock with the initial total time.
		# @parameter total [Numeric] The initial clock duration.
		def initialize(total = 0)
			@total = total
			@started = nil
		end
		
		# Start measuring a duration.
		def start!
			@started ||= Clock.now
		end
		
		# Stop measuring a duration and append the duration to the current total.
		def stop!
			if @started
				@total += (Clock.now - @started)
				@started = nil
			end
			
			return @total
		end
		
		# The total elapsed time including any current duration.
		def total
			total = @total
			
			if @started
				total += (Clock.now - @started)
			end
			
			return total
		end
	end
end
