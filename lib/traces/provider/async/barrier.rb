# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require_relative "../../../async/barrier"
require "traces/provider"

Traces::Provider(Async::Barrier) do
	def wait
		attributes = {
			"size" => self.size
		}
		
		Traces.trace("async.barrier.wait", attributes: attributes) {super}
	end
end
