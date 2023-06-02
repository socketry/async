# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative "../async/reactor"

module Kernel
	def Schedule(...)
		::Async::Task.current.async(...)
	end
end
