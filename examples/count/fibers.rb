#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "async"
require "benchmark"

transitions = []

puts "=========== FIBERS ==========="
puts

count = 0
time = Benchmark.measure do
	Sync do
		5.times do
			[
				Async do
					transitions << "A1"
					puts "Task 1: count is #{count}"
					
					transitions << "A2"
					count += 1
					
					transitions << "A3"
					sleep(0.1)
					
					transitions << "A4"
				end,
				Async do
					transitions << "B1"
					puts "Task 2: count is #{count}"
					
					transitions << "B2"
					count += 1
					
					transitions << "B3"
					sleep(0.1)
					
					transitions << "B4"
				end
			].map(&:wait)
		end
	end
end

puts "#{time.real.round(2)} seconds to run. Final count is #{count}"
puts transitions.join(" ")
