# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require "async/clock"
require "sus/fixtures/time/quantum"

describe Async::Clock do
	let(:clock) {subject.new}
	
	it "can measure durations" do
		duration = Async::Clock.measure do
			sleep 0.01
		end
		
		expect(duration).to be_within(Sus::Fixtures::Time::QUANTUM).of(0.01)
	end
	
	it "can get current offset" do
		expect(Async::Clock.now).to be_a Float
	end
	
	it "can accumulate durations" do
		2.times do
			clock.start!
			sleep(0.01)
			clock.stop!
		end
		
		expect(clock.total).to be_within(2 * Sus::Fixtures::Time::QUANTUM).of(0.02)
	end
	
	with "#total" do
		with "initial duration" do
			let(:clock) {subject.new(1.5)}
			let(:total) {clock.total}
			
			it "computes a sum total" do
				expect(total).to be == 1.5
			end
		end
		
		it "can accumulate time" do
			clock.start!
			total = clock.total
			expect(total).to be >= 0
			sleep(0.0001)
			expect(clock.total).to be >= total
		end
	end
	
	with ".start" do
		let(:clock) {subject.start}
		let(:total) {clock.total}
		
		it "computes a sum total" do
			expect(total).to be >= 0.0
		end
	end
	
	with "#reset!" do
		it "resets the total time" do
			clock.start!
			sleep(0.0001)
			clock.stop!
			expect(clock.total).to be > 0.0
			clock.reset!
			expect(clock.total).to be == 0.0
		end
		
		it "resets the start time" do
			clock.start!
			clock.reset!
			sleep(0.0001)
			expect(clock.total).to be > 0.0
		end
	end
end
