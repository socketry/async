# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "sus/fixtures/async"
require "thread"

describe Thread::Queue do	
	include Sus::Fixtures::Async::ReactorContext
	
	let(:item) {"Hello World"}
	
	it "can pass items between thread and fiber" do
		queue = Thread::Queue.new
		
		Async do
			expect(queue.pop).to be == item
		end
		
		::Thread.new do
			expect(Fiber).to be(:blocking?)
			queue.push(item)
		end.join
	end
end
