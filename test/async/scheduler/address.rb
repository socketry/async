# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

require 'async/scheduler'
require 'sus/fixtures/async'

describe Async::Scheduler do
	include Sus::Fixtures::Async::ReactorContext
	
	describe ::Addrinfo do
		it "can resolve addresses" do
			addresses = Addrinfo.getaddrinfo("www.google.com", "80")
			
			expect(addresses).not.to be(:empty?)
		end
	end
end
