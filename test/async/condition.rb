# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2017-2023, by Samuel Williams.

require 'sus/fixtures/async'
require 'async/condition'

require 'a_condition'

describe Async::Condition do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:condition) {subject.new}
	
	it 'should continue after condition is signalled' do
		task = reactor.async do
			condition.wait
		end
		
		expect(task).to be(:running?)
		
		# This will cause the task to exit:
		condition.signal
		
		expect(task).to be(:completed?)
	end
	
	it 'can stop nested task' do
		producer = nil
		
		consumer = reactor.async do |task|
			condition = Async::Condition.new
			
			producer = task.async do |subtask|
				subtask.yield
				condition.signal
				subtask.sleep(10)
			end
			
			condition.wait
			expect do
				producer.stop
			end.not.to raise_exception
		end
		
		consumer.wait
		producer.wait
		
		expect(producer.status).to be == :stopped
		expect(consumer.status).to be == :completed
	end
	
	it_behaves_like ACondition
end
