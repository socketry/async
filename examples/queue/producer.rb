#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.

require "async"
require "async/queue"

Async do
	# Queue of up to 10 items:
	items = Async::LimitedQueue.new(10)
	
	# Five producers:
	5.times do
		Async do |task|
			while true
				t = rand
				sleep(t)
				items.enqueue(t)
			end
		end
	end
	
	# A single consumer:
	Async do |task|
		while item = items.dequeue
			puts "dequeue -> #{item}"
		end
	end
end
