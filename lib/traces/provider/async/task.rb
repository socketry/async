# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2025, by Samuel Williams.

require_relative "../../../async/task"
require "traces/provider"

Traces::Provider(Async::Task) do
	def schedule(&block)
		# If we are not actively tracing anything, then we can skip this:
		unless Traces.active?
			return super(&block)
		end
		
		unless self.transient?
			trace_context = Traces.trace_context
		end
		
		attributes = {
			# We use the instance variable as it corresponds to the user-provided block.
			"block" => @block.to_s,
			"transient" => self.transient?,
		}
		
		# Run the trace in the context of the child task:
		super do
			Traces.trace_context = trace_context
			
			if annotation = self.annotation
				attributes["annotation"] = annotation
			end
			
			Traces.trace("async.task", attributes: attributes) do
				# Yes, this is correct, we already called super above:
				yield
			end
		end
	end
end
