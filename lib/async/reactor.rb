# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2018, by Sokolov Yura.

require_relative "scheduler"

module Async
	# A wrapper around the the scheduler which binds it to the current thread automatically.
	class Reactor < Scheduler
		# @deprecated Replaced by {Kernel::Async}.
		def self.run(...)
			warn("`Async::Reactor.run{}` is deprecated, use `Async{}` instead.", uplevel: 1, category: :deprecated) if $VERBOSE
			
			Async(...)
		end
		
		# Initialize the reactor and assign it to the current Fiber scheduler.
		def initialize(...)
			super
			
			Fiber.set_scheduler(self)
		end
		
		# Close the reactor and remove it from the current Fiber scheduler.
		def scheduler_close
			self.close
		end
		
		public :sleep
	end
end
