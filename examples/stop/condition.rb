#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require_relative '../../lib/async'; require_relative '../../lib/async/queue'

Async do |consumer|
	consumer.annotate "consumer"
	condition = Async::Condition.new
	
	producer = Async do |subtask|
		subtask.annotate "subtask"
		
		(1..).each do |value|
			puts "producer yielding"
			subtask.yield # (1) Fiber.yield, (3) Reactor -> producer.resume
			condition.signal(value) # (4) consumer.resume(value)
		end
		
		puts "producer exiting"
	end
	
	value = condition.wait # (2) value = Fiber.yield
	puts "producer.stop"
	producer.stop # (5) [producer is resumed already] producer.stop
	
	puts "consumer exiting"
end

puts "Done."
