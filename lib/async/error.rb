# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Async
	# Raised if a timeout occurs on a specific Fiber. Handled gracefully by `Task`.
	# @public Since *Async v1*.
	class TimeoutError < StandardError
		# Create a new timeout error.
		#
		# @parameter message [String] The error message.
		def initialize(message = "execution expired")
			super
		end
	end
end
