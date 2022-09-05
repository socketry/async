# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/scheduler'

require 'timeout'

RSpec.describe Async::Scheduler, if: Async::Scheduler.supported? do
	include_context Async::RSpec::Reactor
	
	describe ::Timeout do
		it "can invoke timeout and receive timeout as block argument" do
			::Timeout.timeout(1.0) do |duration|
				expect(duration).to be == 1.0
			end
		end
	end
end
