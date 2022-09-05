# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.

require 'async/rspec'
require 'async/notification'

require_relative 'condition_examples'

RSpec.describe Async::Notification do
	include_context Async::RSpec::Reactor
	
	it 'should continue after notification is signalled' do
		sequence = []
		
		task = reactor.async do
			sequence << :waiting
			subject.wait
			sequence << :resumed
		end
		
		expect(task.status).to be :running
		
		sequence << :running
		# This will cause the task to exit:
		subject.signal
		sequence << :signalled
		
		expect(task.status).to be :running
		
		sequence << :yielding
		reactor.yield
		sequence << :finished
		
		expect(task.status).to be :complete
		
		expect(sequence).to be == [
			:waiting,
			:running,
			:signalled,
			:yielding,
			:resumed,
			:finished
		]
	end
	
	it_behaves_like Async::Condition
end
