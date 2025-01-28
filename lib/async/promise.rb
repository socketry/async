# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Patrik Wenger.

require_relative "variable"

module Async

	# Similar to a Variable, in that it allows a task to wait for a value to resolve, but also supports rejection given
	# an error. The given error is raised as an exception in the waiting task.
	class Promise < Variable
		def initialize(...)
			super

			@error = nil
		end

		def reject(error = RuntimeError.new('promise rejected'), value = nil)
			@error = error
			resolve value
		end

		def rejected?
			resolved? && !!@error
		end

		# @returns [Boolean] Whether the value has been resolved.
		# @raises [Exception] The error with which this Variable was rejected
		def wait
			value = super
			raise @error if @error
			return value
		end
	end
end
