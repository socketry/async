# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/rspec'
require 'thread'

RSpec.describe Thread::Queue do	
	include_context Async::RSpec::Reactor
	
	let(:item) {"Hello World"}
	
	it "can pass items between thread and fiber" do
		Async do
			expect(subject.pop).to be == item
		end
		
		::Thread.new do
			expect(Fiber).to be_blocking
			subject.push(item)
		end.join
	end
end
