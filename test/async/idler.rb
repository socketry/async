# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'async/idler'
require 'sus/fixtures/async'

require 'chainable_async'

describe Async::Idler do
	include Sus::Fixtures::Async::ReactorContext
	let(:idler) {subject.new(0.5)}
	
	it 'can schedule tasks up to the desired load' do
		# Generate the load:
		Async do
			while true
				idler.async do
					while true
						sleep 0.1
					end
				end
			end
		end
		
		# This test must be longer than the test window...
		sleep 1.1
		
		# Verify that the load is within the desired range:
		expect(Fiber.scheduler.load).to be_within(0.1).of(0.5)
	end
	
	it_behaves_like ChainableAsync
end
