#!/usr/bin/env ruby

require_relative 'lib/async'

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

32.times.map do |thread_index|
	Thread.new do
		100.times do |repeat|
			wait_for_interrupt(thread_index, repeat)
		end
	end
end.each(&:join)
