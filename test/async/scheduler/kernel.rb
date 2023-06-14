# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2023, by Samuel Williams.

require 'async/scheduler'
require 'sus/fixtures/async'
require 'timer_quantum'

describe Async::Scheduler do
	include Sus::Fixtures::Async::ReactorContext
	
	describe ::Kernel do
		let(:duration) {0.01}
		
		it "can sleep for a short duration" do
			expect(reactor).to receive(:kernel_sleep).with(duration)
			
			time_taken = Async::Clock.measure do
				sleep(duration)
			end
			
			expect(time_taken).to be_within(Q).of(duration)
		end
		
		it "can sleep forever" do
			expect(reactor).to receive(:kernel_sleep).with()
			
			sleeping = reactor.async do
				sleep
			end
			
			sleeping.stop
		end
	end
end
