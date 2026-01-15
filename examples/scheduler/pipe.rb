#!/usr/bin/env ruby
# frozen_string_literal: true

puts "Starting..."

require_relative '../../lib/async'
require_relative '../../lib/async/scheduler'

require 'io/nonblock'

thread = Thread.current

abort "Require Thread\#selector patch" unless thread.respond_to?(:selector)

MESSAGE = "Helloooooo World!"

Async do |task|
	scheduler = Async::Scheduler.new(task.reactor)
	
	thread.selector = scheduler
	
	input, output = IO.pipe
	input.nonblock = true
	output.nonblock = true
	
	task.async do
		MESSAGE.each_char do |character|
			puts "Writing: #{character}"
			output.write(character)
			sleep(1)
		end
		
		output.close
	end
	
	input.each_char do |character|
		puts "#{Async::Clock.now}: #{character}"
	end
	
	puts "Closing"
	input.close
ensure
	thread.selector = nil
end

puts "Done"