# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/group'
require 'sus/fixtures/async'

describe Async::Group do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:group) {subject.new}
	
	it 'can wait for all tasks to finish' do
		task = group.async do
			sleep 0.001
		end
		
		expect(task.status).to be == :running
		
		group.wait
		
		expect(task.status).to be == :complete
	end
end
