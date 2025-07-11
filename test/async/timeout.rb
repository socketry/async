# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/async"

describe Async::Timeout do
	include Sus::Fixtures::Async::ReactorContext
	
	it "can schedule a timeout" do
		scheduler.with_timeout(1) do |timeout|
			expect(timeout.time).to be >= 0
			expect(timeout.duration).to (be > 0).and(be <= 1)
		end
	end
	
	with "#now" do
		it "can get the current time" do
			scheduler.with_timeout(1) do |timeout|
				expect(timeout.now).to be >= 0
				expect(timeout.now).to be <= timeout.time
			end
		end
	end
	
	with "#adjust" do
		it "can adjust the timeout" do
			scheduler.with_timeout(1) do |timeout|
				timeout.adjust(1)
				expect(timeout.duration).to (be > 1).and(be <= 2)
			end
		end
	end
	
	with "#duration=" do
		it "can set the timeout duration" do
			scheduler.with_timeout(1) do |timeout|
				timeout.duration = 2
				expect(timeout.duration).to (be > 1).and(be <= 2)
			end
		end
		
		it "can increase the timeout duration" do
			scheduler.with_timeout(1) do |timeout|
				timeout.duration += 2
				expect(timeout.duration).to (be > 2).and(be <= 3)
			end
		end
	end
	
	with "#time=" do
		it "can set the timeout time" do
			scheduler.with_timeout(1) do |timeout|
				timeout.time = timeout.time + 1
				expect(timeout.duration).to (be > 1).and(be < 2)
			end
		end
	end
	
	with "#cancel!" do
		it "can cancel the timeout" do
			scheduler.with_timeout(1) do |timeout|
				timeout.cancel!
				expect(timeout).to be(:cancelled?)
			end
		end
		
		it "can't reschedule a cancelled timeout" do
			scheduler.with_timeout(1) do |timeout|
				timeout.cancel!
				expect do
					timeout.adjust(1)
				end.to raise_exception(Async::Timeout::CancelledError)
			end
		end
	end
end
