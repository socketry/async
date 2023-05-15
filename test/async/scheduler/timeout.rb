# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/scheduler'
require 'sus/fixtures/async'
require 'timeout'

describe Async::Scheduler do
	include Sus::Fixtures::Async::ReactorContext
	
	describe ::Timeout do
		it "can invoke timeout and receive timeout as block argument" do
			::Timeout.timeout(1.0) do |duration|
				expect(duration).to be == 1.0
			end
		end
	end
end
