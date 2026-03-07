# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "console"

module Async
	# @namespace
	module Loop
		# Execute a block repeatedly at quantized (time-aligned) intervals.
		#
		# The alignment is computed modulo the current clock time in seconds. For example, with
		# `interval: 60`, executions will occur at 00:00, 01:00, 02:00, etc., regardless of when
		# the loop is started. With `interval: 300` (5 minutes), executions align to 00:00, 00:05,
		# 00:10, etc.
		#
		# This is particularly useful for tasks that should run at predictable wall-clock times,
		# such as metrics collection, periodic cleanup, or scheduled jobs that need to align
		# across multiple processes.
		#
		# If an error occurs during block execution, it is logged and the loop continues.
		#
		# @example Run every minute at :00 seconds:
		# 	Async::Loop.quantized(interval: 60) do
		# 		puts "Current time: #{Time.now}"
		# 	end
		#
		# @example Run every 5 minutes aligned to the hour:
		# 	Async::Loop.quantized(interval: 300) do
		# 		collect_metrics
		# 	end
		#
		# @parameter interval [Numeric] The interval in seconds. Executions will align to multiples of this interval based on the current time.
		# @yields The block to execute at each interval.
		#
		# @public Since *Async v2.37*.
		def self.quantized(interval: 60, &block)
			while true
				# Compute the wait time to the next interval:
				wait = interval - (Time.now.to_f % interval)
				if wait.positive?
					# Sleep until the next interval boundary:
					sleep(wait)
				end
				
				begin
					yield
				rescue => error
					Console.error(self, "Loop error:", error)
				end
			end
		end
		
		# Execute a block repeatedly with a fixed delay between executions.
		#
		# Unlike {quantized}, this method waits for the specified interval *after* each execution
		# completes. This means the actual time between the start of successive executions will be
		# `interval + execution_time`.
		#
		# If an error occurs during block execution, it is logged and the loop continues.
		#
		# @example Run every 5 seconds (plus execution time):
		# 	Async::Loop.periodic(interval: 5) do
		# 		process_queue
		# 	end
		#
		# @parameter interval [Numeric] The delay in seconds between executions.
		# @yields The block to execute periodically.
		#
		# @public Since *Async v2.37*.
		def self.periodic(interval: 60, &block)
			while true
				begin
					yield
				rescue => error
					Console.error(self, "Loop error:", error)
				end
				
				sleep(interval)
			end
		end
	end
end
