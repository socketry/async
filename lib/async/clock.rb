# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.

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
