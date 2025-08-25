# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "traces"
return unless Traces.enabled?

require "async"
require "traces/provider/async/task"

describe Async::Task do
	it "traces tasks within active tracing" do
		parent_context = child_context = nil
		
		Thread.new do
			Traces.trace("parent") do
				parent_context = Traces.trace_context
				
				Async do
					child_context = Traces.trace_context
				end
			end
		end.join
		
		expect(child_context).to have_attributes(
			trace_id: be == parent_context.trace_id
		)
	end
	
	it "doesn't trace tasks outside of active tracing" do
		expect(Traces).to receive(:active?).and_return(false)
		
		context = nil
		
		Async do
			context = Traces.trace_context
		end
		
		expect(context).to be == nil
	end
end
