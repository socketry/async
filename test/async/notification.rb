# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2023, by Samuel Williams.

require 'sus/fixtures/async'
require 'async/notification'

require 'a_condition'

describe Async::Notification do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:notification) {subject.new}
	
	it 'should continue after notification is signalled' do
		sequence = []
		
		task = reactor.async do
			sequence << :waiting
			notification.wait
			sequence << :resumed
		end
		
		expect(task.status).to be == :running
		
		sequence << :running
		# This will cause the task to exit:
		notification.signal
		sequence << :signalled
		
		expect(task.status).to be == :running
		
		sequence << :yielding
		reactor.yield
		sequence << :finished
		
		expect(task.status).to be == :completed
		
		expect(sequence).to be == [
			:waiting,
			:running,
			:signalled,
			:yielding,
			:resumed,
			:finished
		]
	end
	
	it_behaves_like ACondition
end
