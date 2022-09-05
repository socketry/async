# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

require 'async/scheduler'

RSpec.describe Async::Scheduler, if: Async::Scheduler.supported? do
	include_context Async::RSpec::Reactor
	
	describe ::Addrinfo do
		it "can resolve addresses" do
			addresses = Addrinfo.getaddrinfo("www.google.com", "80")
			
			expect(addresses).to_not be_empty
		end
	end
end
