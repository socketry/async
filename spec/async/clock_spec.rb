# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.

require 'async/clock'

RSpec.describe Async::Clock do
	it "can measure durations" do
		duration = Async::Clock.measure do
			sleep 0.1
		end
		
		expect(duration).to be_within(0.01 * Q).of(0.1)
	end
	
	it "can get current offset" do
		expect(Async::Clock.now).to be_kind_of Float
	end
	
	it "can accumulate durations" do
		2.times do
			subject.start!
			sleep(0.1)
			subject.stop!
		end
		
		expect(subject.total).to be_within(0.02 * Q).of(0.2)
	end
	
	describe '#total' do
		context 'with initial duration' do
			let(:clock) {described_class.new(1.5)}
			subject(:total) {clock.total}
			
			it{is_expected.to be == 1.5}
		end
		
		it "can accumulate time" do
			subject.start!
			total = subject.total
			expect(total).to be >= 0
			sleep(0.0001)
			expect(subject.total).to be >= total
		end
	end
	
	describe '.start' do
		let(:clock) {described_class.start}
		subject(:total) {clock.total}
		
		it {is_expected.to be >= 0.0}
	end
end
