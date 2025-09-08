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
	
	with "monotonicity" do
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
	
	with "edge cases" do
		it "handles multiple start/stop cycles" do
			3.times do
				clock.start!
				# Calling start! again should not change the start time
				original_start = clock.instance_variable_get(:@started)
				clock.start!
				expect(clock.instance_variable_get(:@started)).to be == original_start
				clock.stop!
			end
			
			expect(clock.total).to be >= 0
		end
		
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
		
		it "includes running time in total" do
			base_total = clock.total
			expect(base_total).to be == 0
			
			clock.start!
			sleep(0.001)
			running_total = clock.total
			
			expect(running_total).to be > base_total
			expect(clock.instance_variable_get(:@started)).not.to be_nil
		end
	end
	
end
