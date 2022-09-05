# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2017-2022, by Samuel Williams.

require 'async/rspec'
require 'async/condition'

require_relative 'condition_examples'

RSpec.describe Async::Condition, timeout: 1000 do
	include_context Async::RSpec::Reactor
	
	it 'should continue after condition is signalled' do
		task = reactor.async do
			subject.wait
		end
		
		expect(task.status).to be :running
		
		# This will cause the task to exit:
		subject.signal
		
		expect(task.status).to be :complete
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
			end.to_not raise_exception
		end
		
		consumer.wait
		producer.wait
		
		expect(producer.status).to be :stopped
		expect(consumer.status).to be :complete
	end
	
	it_behaves_like Async::Condition
end
