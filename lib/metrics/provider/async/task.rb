# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "../../../async/task"
require "metrics/provider"

Metrics::Provider(Async::Task) do
	ASYNC_TASK_SCHEDULED = Metrics.metric("async.task.scheduled", :counter, description: "The number of tasks scheduled.")
	ASYNC_TASK_FINISHED = Metrics.metric("async.task.finished", :counter, description: "The number of tasks finished.")
	
	def schedule(&block)
		ASYNC_TASK_SCHEDULED.emit(1)
		
		super(&block)
	ensure
		ASYNC_TASK_FINISHED.emit(1)
	end
end
