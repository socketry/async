# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "clock"

module Async
	# Manages a countdown timer for timeout operations.
	# Provides precise deadline tracking for compound operations to prevent timeout accumulation where multiple operations could exceed user timeouts.
	# @public Since *Async v2.31*.
	class Deadline
		# Singleton module for immediate timeouts (zero or negative).
		# Avoids object allocation for performance.
		module Zero
			def self.expired?
				true
			end
			
			def self.remaining
				0
			end
		end
		
		# Create a deadline for the given timeout.
		# @parameter timeout [Numeric | Nil] The timeout duration, or nil for no timeout.
		# @returns [Deadline | Nil] A deadline instance, Zero singleton, or nil.
		def self.start(timeout)
			if timeout.nil?
				nil
			elsif timeout <= 0
				Zero
			else
				self.new(timeout)
			end
		end
		
		# Create a new deadline with the specified remaining time.
		# @parameter remaining [Numeric] The initial remaining time.
		def initialize(remaining)
			@remaining = remaining
			@start = Clock.now
		end
		
		# Get the remaining time, updating internal state.
		# Each call to this method advances the internal clock and reduces
		# the remaining time by the elapsed duration since the last call.
		# @returns [Numeric] The remaining time (may be negative if expired).
		def remaining
			now = Clock.now
			delta = now - @start
			@start = now
			
			@remaining -= delta
			
			return @remaining
		end
		
		# Check if the deadline has expired.
		# @returns [Boolean] True if no time remains.
		def expired?
			self.remaining <= 0
		end
	end
end