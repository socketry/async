# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative "../async/reactor"

module Kernel
	# Run the given block of code in a task, asynchronously, creating a reactor if necessary.
	#
	# The preferred method to invoke asynchronous behavior at the top level.
	#
	# - When invoked within an existing reactor task, it will run the given block
	# asynchronously. Will return the task once it has been scheduled.
	# - When invoked at the top level, will create and run a reactor, and invoke
	# the block as an asynchronous task. Will block until the reactor finishes
	# running.
	#
	# @yields {|task| ...} The block that will execute asynchronously.
	# 	@parameter task [Async::Task] The task that is executing the given block.
	#
	# @public Since `stable-v1`.
	# @asynchronous May block until given block completes executing.
	def Async(...)
		if current = ::Async::Task.current?
			return current.async(...)
		else
			# This calls Fiber.set_scheduler(self):
			reactor = ::Async::Reactor.new
			
			begin
				return reactor.run(...)
			ensure
				Fiber.set_scheduler(nil)
			end
		end
	end
end
