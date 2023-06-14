#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

# This bug only generally shows up on Linux, when using io_uring, as it has more fine-grained locking. The issue is that `puts` can acquire and release a write lock, and if one thread releases that lock while the reactor on the waitq thread is closing, it can call `unblock` with `@selector = nil` which fails or causes odd behaviour.

require_relative '../../lib/async'

def wait_for_interrupt(thread_index, repeat)
	sequence = []
	
	events = Thread::Queue.new
	reactor = Async::Reactor.new
	
	thread = Thread.new do
		if events.pop
			puts "#{thread_index}+#{repeat} Sending Interrupt!"
			reactor.interrupt
		end
	end
	
	reactor.async do
		events << true
		puts "#{thread_index}+#{repeat} Reactor ready!"
		
		# Wait to be interrupted:
		sleep(1)
		
		puts "#{thread_index}+#{repeat} Missing interrupt!"
	end
	
	reactor.run
	
	thread.join
end

100.times.map do |thread_index|
	Thread.new do
		1000.times do |repeat|
			wait_for_interrupt(thread_index, repeat)
		end
	end
end.each(&:join)
