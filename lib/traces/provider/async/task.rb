# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require_relative "../../../async/task"
require "traces/provider"

Traces::Provider(Async::Task) do
	def schedule(&block)
		unless self.transient?
			trace_context = Traces.trace_context
		end
		
		super do
			Traces.trace_context = trace_context
			
			if annotation = self.annotation
				attributes = {
					"annotation" => annotation
				}
			end
			
			Traces.trace("async.task", attributes: attributes) do
				yield
			end
		end
	end
end
