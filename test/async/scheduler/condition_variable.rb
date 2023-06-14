# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2023, by Samuel Williams.

require 'async/scheduler'
require 'sus/fixtures/async'

describe Async::Scheduler do
	include Sus::Fixtures::Async::ReactorContext
	
	describe ::ConditionVariable do
		let(:mutex) {Mutex.new}
		let(:condition) {ConditionVariable.new}
		let(:timeout) {5.0}
		
		it "can signal between tasks" do
			time_taken = nil
			
			waiter = reactor.async do
				mutex.synchronize do
					time_taken = Async::Clock.measure do
						condition.wait(mutex, timeout)
					end
				end
			end
			
			signaller = reactor.async do
				mutex.synchronize do
					condition.signal
				end
			end
			
			signaller.wait
			waiter.wait
			
			expect(time_taken).to be < timeout
		end
	end
end
