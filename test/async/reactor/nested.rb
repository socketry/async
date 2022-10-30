# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.

describe Async::Reactor do
	with '.run (in existing reactor)' do
		include Sus::Fixtures::Async::ReactorContext
		
		it "should nest reactor" do
			outer_reactor = Async::Task.current.reactor
			inner_reactor = nil
			
			subject.run do |task|
				inner_reactor = task.reactor
			end
			
			expect(outer_reactor).to be_a(subject)
			expect(outer_reactor).to be_equal(inner_reactor)
		end
	end
	
	with '::run' do
		it "should nest reactor" do
			expect(Async::Task.current?).to be_nil
			inner_reactor = nil
			
			subject.run do |task|
				inner_reactor = task.reactor
			end
			
			expect(inner_reactor).to be_a(subject)
		end
	end
end
