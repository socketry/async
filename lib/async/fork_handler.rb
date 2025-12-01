# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

module Async
	# Private module that hooks into Process._fork to handle fork events.
	#
	# If `Scheduler#process_fork` hook is adopted in Ruby 4, this code can be removed after Ruby < 4 is no longer supported.
	module ForkHandler
		def _fork(&block)
			result = super
			
			if result.zero?
				# Child process:
				if Fiber.scheduler.respond_to?(:process_fork)
					Fiber.scheduler.process_fork
				end
			end
			
			return result
		end
	end
	
	private_constant :ForkHandler
	
	# Hook into Process._fork to handle fork events automatically:
	unless (Fiber.const_get(:SCHEDULER_PROCESS_FORK) rescue false)
		::Process.singleton_class.prepend(ForkHandler)
	end
end
