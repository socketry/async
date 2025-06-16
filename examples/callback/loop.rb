#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

# frozen_string_literal: true

require "async/reactor"

class Callback
	def initialize
		@reactor = Async::Reactor.new
	end
	
	def close
		@reactor.close
	end
	
	# If duration is 0, it will happen immediately after the task is started.
	def run(duration = 0, &block)
		if block_given?
			@reactor.async(&block)
		end
		
		@reactor.run_once(duration)
	end
end


callback = Callback.new

begin
	callback.run do |task|
		while true
			sleep(2)
			puts "Hello from task!"
		end
	end
	
	while true
		callback.run(0)
		puts "Sleeping for 1 second"
		sleep(1)
	end
ensure
	callback.close
end
