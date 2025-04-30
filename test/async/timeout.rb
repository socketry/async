# frozen_string_literal: true
require "sus/fixtures/async"

describe Async::Timeout do
	include Sus::Fixtures::Async::ReactorContext
	
	it "can schedule a timeout" do
		scheduler.with_timeout(1) do |timeout|
			expect(timeout.time).to be >= 0
			expect(timeout.duration).to be == 1
		end
	end
	
	with "#adjust" do
		it "can adjust the timeout" do
			scheduler.with_timeout(1) do |timeout|
				timeout.adjust(1)
				expect(timeout.duration).to be == 2
			end
		end
	end
	
	with "#duration=" do
		it "can set the timeout duration" do
			scheduler.with_timeout(1) do |timeout|
				timeout.duration = 2
				expect(timeout.duration).to be == 2
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
	end
end
