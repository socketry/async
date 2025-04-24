# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "traces"
return unless Traces.enabled?

require "async"
require "traces/provider/async/task"

describe Async::Task do
	it "traces tasks within active tracing" do
		context = nil
		
		Thread.new do
			Traces.trace("test") do
				Async do
					context = Traces.trace_context
				end
			end
		end.join
		
		expect(context).not.to be == nil
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
