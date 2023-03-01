# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

puts RUBY_VERSION

times = []

10.times do
	start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
	
	fibers = 10_000.times.map do
		Fiber.new do
			true
		end
	end
	
	fibers.each(&:resume)
	
	duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
	duration_us = duration * 1_000_000
	duration_per_iteration = duration_us / fibers.size
	
	times << duration_per_iteration
	puts "Fiber duration: #{duration_per_iteration.round(2)}us"
end

puts "Average: #{(times.sum / times.size).round(2)}us"
puts "   Best: #{times.min.round(2)}us"
