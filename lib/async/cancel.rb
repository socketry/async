# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Async
	# Raised when a task is explicitly cancelled.
	class Cancel < Exception
		# Represents the source of the cancel operation.
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
			
			# Create a new cause of the cancel operation, with the given message.
			#
			# @parameter message [String] The error message.
			# @returns [Cause] The cause of the cancel operation.
			def self.for(message = "Task was cancelled!")
				instance = self.new(message)
				instance.set_backtrace(self.backtrace)
				return instance
			end
		end
		
		if RUBY_VERSION < "3.5"
			# Create a new cancel operation.
			#
			# This is a compatibility method for Ruby versions before 3.5 where cause is not propagated correctly when using {Fiber#raise}
			#
			# @parameter message [String | Hash] The error message or a hash containing the cause.
			def initialize(message = "Task was cancelled")
				
				if message.is_a?(Hash)
					@cause = message[:cause]
					message = "Task was cancelled"
				end
				
				super(message)
			end
			
			# @returns [Exception] The cause of the cancel operation.
			#
			# This is a compatibility method for Ruby versions before 3.5 where cause is not propagated correctly when using {Fiber#raise}, we explicitly capture the cause here.
			def cause
				super || @cause
			end
		end
		
		# Used to defer cancelling the current task until later.
		class Later
			# Create a new cancel later operation.
			#
			# @parameter task [Task] The task to cancel later.
			# @parameter cause [Exception] The cause of the cancel operation.
			def initialize(task, cause = nil)
				@task = task
				@cause = cause
			end
			
			# @returns [Boolean] Whether the task is alive.
			def alive?
				true
			end
			
			# Transfer control to the operation - this will cancel the task.
			def transfer
				@task.cancel(false, cause: @cause)
			end
		end
	end
end
