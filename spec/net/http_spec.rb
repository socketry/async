# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/rspec'
require 'net/http'

RSpec.describe Net::HTTP do
	include_context Async::RSpec::Reactor

	it "can make several concurrent requests" do
		barrier = Async::Barrier.new
		events = []
		
		3.times do |i|
			barrier.async do
				events << i
				response = Net::HTTP.get(URI "https://www.google.com/search?q=ruby")
				expect(response).to_not be_nil
				events << i
			end
		end
		
		barrier.wait
		
		# The requests all get started concurrently:
		expect(events.first(3)).to be == [0, 1, 2]
	end
end
