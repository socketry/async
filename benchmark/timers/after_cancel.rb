#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "benchmark/ips"

require "timers"
require "io/event/timers"

Benchmark.ips do |benchmark|
	benchmark.time = 1
	benchmark.warmup = 1
	
	benchmark.report("Timers::Group") do |count|
		timers = Timers::Group.new
		
		while count > 0
			timer = timers.after(0) {}
			timer.cancel
			count -= 1
		end
		
		timers.fire
	end
	
	benchmark.report("IO::Event::Timers") do |count|
		timers = IO::Event::Timers.new
		
		while count > 0
			timer = timers.after(0) {}
			timer.cancel!
			count -= 1
		end
		
		timers.fire
	end
	
	benchmark.compare!
end
