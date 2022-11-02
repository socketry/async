# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.
# Copyright, 2020, by Brian Morearty.

require_relative "../async/reactor"

# Extensions to all Ruby objects.
module Kernel
	# Run the given block of code synchronously, but within a reactor if not already in one.
	#
	# @yields {|task| ...} The block that will execute asynchronously.
	# 	@parameter task [Async::Task] The task that is executing the given block.
	#
	# @public Since `stable-v1`.
	# @asynchronous Will block until given block completes executing.
	def Sync(&block)
		if task = ::Async::Task.current?
			yield task
		else
			# This calls Fiber.set_scheduler(self):
			reactor = Async::Reactor.new
			
			begin
				return reactor.run(finished: ::Async::Condition.new, &block).wait
			ensure
				Fiber.set_scheduler(nil)
			end
		end
	end
end
