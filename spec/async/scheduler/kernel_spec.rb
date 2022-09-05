# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

require 'async/scheduler'

RSpec.describe Async::Scheduler, if: Async::Scheduler.supported? do
	include_context Async::RSpec::Reactor
	
	describe ::Kernel do
		let(:duration) {0.1}
		
		it "can sleep for a short duration" do
			expect(reactor).to receive(:kernel_sleep).with(duration).and_call_original
			
			time_taken = Async::Clock.measure do
				sleep(duration)
			end
			
			expect(time_taken).to be_within(Q).of(duration)
		end
		
		it "can sleep forever" do
			expect(reactor).to receive(:kernel_sleep).with(no_args).and_call_original
			
			sleeping = reactor.async do
				sleep
			end
			
			sleeping.stop
		end
	end
end
