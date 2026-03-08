# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024-2026, by Samuel Williams.

require "async/idler"
require "sus/fixtures/async"

require "async/chainable_async"

describe Async::Idler do
	include Sus::Fixtures::Async::ReactorContext
	let(:idler) {subject.new(0.5)}
	
	it "can schedule tasks up to the desired load" do
		expect(Fiber.scheduler.load).to be < 0.1
		slept = Async::Promise.new
		
		mock(idler) do |mock|
			mock.after(:sleep) do
				slept.resolve(Fiber.scheduler.load)
			end
		end
		
		# Generate the load:
		task = Async do
			while true
				idler.async do
					while true
						sleep 0.1
					end
				end
			end
		end
		
		expect(slept.wait).to be >= 0.5
	ensure
		task.stop
	end
	
	it_behaves_like Async::ChainableAsync
end
