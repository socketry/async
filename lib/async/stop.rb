# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "fiber"
require "console"

module Async
	# Raised when a task is explicitly stopped.
	class Stop < Exception
		# Represents the source of the stop operation.
		class Cause < Exception
			if RUBY_VERSION >= "3.4"
				# @returns [Array(Thread::Backtrace::Location)] The backtrace of the caller.
				def self.backtrace
					caller_locations(2..-1)
				end
			else
				# @returns [Array(String)] The backtrace of the caller.
				def self.backtrace
					caller(2..-1)
				end
			end
			
			# Create a new cause of the stop operation, with the given message.
			#
			# @parameter message [String] The error message.
			# @returns [Cause] The cause of the stop operation.
			def self.for(message = "Task was stopped")
				instance = self.new(message)
				instance.set_backtrace(self.backtrace)
				return instance
			end
		end
		
		if RUBY_VERSION < "3.5"
			# Create a new stop operation.
			#
			# This is a compatibility method for Ruby versions before 3.5 where cause is not propagated correctly when using {Fiber#raise}
			#
			# @parameter message [String | Hash] The error message or a hash containing the cause.
			def initialize(message = "Task was stopped")
				if message.is_a?(Hash)
					@cause = message[:cause]
					message = "Task was stopped"
				end
				
				super(message)
			end
			
			# @returns [Exception] The cause of the stop operation.
			#
			# This is a compatibility method for Ruby versions before 3.5 where cause is not propagated correctly when using {Fiber#raise}, we explicitly capture the cause here.
			def cause
				super || @cause
			end
		end
		
		# Used to defer stopping the current task until later.
		class Later
			# Create a new stop later operation.
			#
			# @parameter task [Task] The task to stop later.
			# @parameter cause [Exception] The cause of the stop operation.
			def initialize(task, cause = nil)
				@task = task
				@cause = cause
			end
			
			# @returns [Boolean] Whether the task is alive.
			def alive?
				true
			end
			
			# Transfer control to the operation - this will stop the task.
			def transfer
				@task.stop(false, cause: @cause)
			end
		end
	end
end
