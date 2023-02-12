puts RUBY_VERSION

times = []

10.times do
	start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
	
	threads = 20_000.times.map do
		Thread.new do
			true
		end
	end
	
	threads.each(&:join)
	
	duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
	duration_us = duration * 1_000_000
	duration_per_iteration = duration_us / threads.size
	
	times << duration_per_iteration
	puts "Thread duration: #{duration_per_iteration.round(2)}us"
end

puts "Average: #{(times.sum / times.size).round(2)}us"
puts "   Best: #{times.min.round(2)}us"
