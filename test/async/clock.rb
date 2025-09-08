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
	
	with "#start" do
		it "handles multiple start/stop cycles" do
			3.times do
				clock.start!
				# Calling start! again should be idempotent - no time should be added
				first_total = clock.total
				clock.start!
				second_total = clock.total
				
				# The total should not jump significantly just from calling start! again
				expect(second_total - first_total).to be < 0.001
				clock.stop!
			end
			
			expect(clock.total).to be >= 0
		end
	end
	
	with "#stop" do
		it "handles stop without start" do
			result = clock.stop!
			expect(result).to be == 0
			expect(clock.total).to be == 0
		end

		it "handles multiple stops" do
			clock.start!
			first_stop = clock.stop!
			second_stop = clock.stop!
			
			expect(first_stop).to be == second_stop
			expect(clock.total).to be == first_stop
		end
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

		it "preserves total during start/stop cycles" do
			# First cycle
			clock.start!
			sleep(0.001)
			first_total = clock.stop!
			
			# Second cycle
			clock.start!
			sleep(0.001)
			second_total = clock.stop!
			
			expect(second_total).to be > first_total
			expect(clock.total).to be == second_total
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
	
	with ".now" do
		it "produces monotonic timestamps" do
			first = Async::Clock.now
			second = Async::Clock.now
			third = Async::Clock.now
			
			expect(second).to be >= first
			expect(third).to be >= second
		end
		
		it "measures positive durations" do
			duration = Async::Clock.measure do
				# Even minimal operations should have non-negative duration
			end
			
			expect(duration).to be >= 0
		end
	end
end
