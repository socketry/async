# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2024, by Samuel Williams.

require "async/scheduler"
require "sus/fixtures/async"

describe Async::Scheduler do
	include Sus::Fixtures::Async::ReactorContext
	
	describe ::Addrinfo do
		it "can resolve addresses" do
			addresses = Addrinfo.getaddrinfo("www.google.com", "80")
			
			expect(addresses).not.to be(:empty?)
		end
		
		it "can resolve ipv4 addresses" do
			address = Addrinfo.getaddrinfo("127.0.0.1", "80").first
			
			expect(address.ipv4?).to be == true
		end
		
		it "can resolve ipv6 addresses" do
			address = Addrinfo.getaddrinfo("::1", "80").first
			
			expect(address.ipv6?).to be == true
		end
		
		it "can resolve ipv6 addresses with device suffix" do
			address = Addrinfo.getaddrinfo("::1%lo0", "80").first
			
			expect(address.ipv6?).to be == true
		end
	end
end
