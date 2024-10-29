# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "sus/fixtures/async"
require "net/http"
require "async/barrier"
require "openssl"

describe Net::HTTP do
	include Sus::Fixtures::Async::ReactorContext
	let(:timeout) {10}
	
	it "can make several concurrent requests" do
		barrier = Async::Barrier.new
		events = []
		
		3.times do |i|
			barrier.async do
				events << i
				response = Net::HTTP.get(URI "https://github.com/")
				expect(response).not.to be == nil
				events << i
			end
		end
		
		barrier.wait
		
		# The requests all get started concurrently:
		expect(events.first(3)).to be == [0, 1, 2]
	end
end
