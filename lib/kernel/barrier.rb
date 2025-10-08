# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require_relative "sync"
require_relative "../async/barrier"
require_relative "../async/idler"

module Kernel
	# Create a barrier, yield it to the block, and then wait for all tasks to complete.
	#
	# If no scheduler is running, one will be created automatically for the duration of the block.
	#
	# By default, the barrier uses an `Async::Idler` to manage load, but this can be overridden by providing a different parent or `nil` to disable load management.
	#
	# @parameter parent [Task | Semaphore | Nil] The parent for holding any children tasks.
	# @parameter **options [Hash] Additional options passed to {Kernel::Sync}.
	# @public Since *Async v2.34*.
	def Barrier(parent: Async::Idler.new, **options)
		Sync(**options) do |task|
			barrier = ::Async::Barrier.new(parent: parent)
			
			yield barrier
			
			barrier.wait
		ensure
			barrier&.stop
		end
	end
end
