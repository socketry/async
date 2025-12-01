# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2020, by Brian Morearty.
# Copyright, 2024, by Patrik Wenger.
# Copyright, 2025, by Shopify Inc.

require_relative "../async/reactor"

# Extensions to all Ruby objects.
module Kernel
	# Run the given block of code synchronously, but within a reactor if not already in one.
	#
	# @yields {|task| ...} The block that will execute asynchronously.
	# 	@parameter task [Async::Task] The task that is executing the given block.
	#
	# @public Since *Async v1*.
	# @asynchronous Will block until given block completes executing.
	def Sync(annotation: nil, &block)
		if task = ::Async::Task.current?
			if annotation
				task.annotate(annotation){yield task}
			else
				yield task
			end
		elsif scheduler = Fiber.scheduler
			::Async::Task.run(scheduler, &block).wait
		else
			# This calls Fiber.set_scheduler(self):
			reactor = Async::Reactor.new
			
			begin
				# Use finished: false to suppress warnings since we're handling exceptions explicitly
				task = reactor.async(annotation: annotation, finished: false, &block)
				reactor.run
				return task.wait
			ensure
				Fiber.set_scheduler(nil)
			end
		end
	end
end
