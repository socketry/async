# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "../../../async/task"
require "metrics/provider"

Metrics::Provider(Async::Task) do
	ASYNC_TASK_SCHEDULED = Metrics.metric("async.task.scheduled", :counter, description: "The number of tasks scheduled.")
	
	def schedule(&block)
		ASYNC_TASK_SCHEDULED.emit(1)
		
		super(&block)
	end
end
