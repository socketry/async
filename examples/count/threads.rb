#!/usr/bin/env ruby

require 'benchmark'

transitions = []

puts "=========== THREADS ==========="
puts
count = 0
time = Benchmark.measure do
	5.times do
		[
			Thread.new do                       ; transitions << "A1"
				puts "Task 1: count is #{count}"  ; transitions << "A2"
				count += 1                        ; transitions << "A3"
				sleep(0.1)                        ; transitions << "A4"
			end,
			Thread.new do                       ; transitions << "B1"
				puts "Task 2: count is #{count}"  ; transitions << "B2"
				count += 1                        ; transitions << "B3"
				sleep(0.1)                        ; transitions << "B4"
			end
		].map(&:join)
	end
end
puts "#{time.real.round(2)} seconds to run. Final count is #{count}"
puts transitions.join(" ")