# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Internal
		module BlockingOperationWaitInline
			def blocking_operation_wait(work)
				Fiber.blocking{work.call}
			end
		end
	end
end
