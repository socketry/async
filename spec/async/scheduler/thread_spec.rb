# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

require 'async/scheduler'

RSpec.describe Async::Scheduler, if: Async::Scheduler.supported? do
	include_context Async::RSpec::Reactor
	
	describe ::Thread do
		# I saw this hang.
		it "can wait for value" do
			value = Thread.new do
				sleep(0)
				:value
			end.value
			
			expect(value).to be == :value
		end
		
		it "can propagate exception" do
			thread = nil
			
			task = Async do
				begin
					thread = Thread.new do
						sleep
					end
					
					thread.join
				ensure
					thread.kill
					thread.join
				end
			end
			
			task.stop
			task.wait
			
			expect(thread).to_not be_alive
		end
	end
end
