# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2018, by Sokolov Yura.

require_relative 'scheduler'

module Async
	# A wrapper around the the scheduler which binds it to the current thread automatically.
	class Reactor < Scheduler
		# @deprecated Replaced by {Kernel::Async}.
		def self.run(...)
			Async(...)
		end
		
		def initialize(...)
			super
			
			Fiber.set_scheduler(self)
		end
		
		def scheduler_close
			self.close
		end
		
		public :sleep
	end
end
