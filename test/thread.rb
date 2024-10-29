# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "thread"
require "sus/fixtures/async"

describe Thread do
	include Sus::Fixtures::Async::ReactorContext
	
	it "can join thread" do
		queue = Thread::Queue.new
		thread = Thread.new{queue.pop}
		
		waiting = 0
		
		3.times do
			Async do
				waiting += 1
				thread.join
				waiting -= 1
			end
		end
		
		expect(waiting).to be == 3
		queue.close
	end
end
