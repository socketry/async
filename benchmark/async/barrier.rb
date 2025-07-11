# frozen_string_literal: true

# Copyright, 2025, by Samuel Williams.

require "async/barrier"

require "sus/fixtures/async/scheduler_context"
require "sus/fixtures/benchmark"

describe Async::Barrier do
	include Sus::Fixtures::Async::SchedulerContext
	include Sus::Fixtures::Benchmark
	
	measure "can schedule several tasks quickly" do |repeats|
		barrier = Async::Barrier.new
		
		repeats.times do |i|
			barrier.async{}
		end
		
		barrier.wait
	end
end
