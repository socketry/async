# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

class TimerQuantum
	def self.resolve
		self.new.to_f
	end
	
	def to_f
		precision
	end
	
	private
	
	def precision
		@precision ||= self.measure_host_precision
	end
	
	def measure_host_precision(repeats: 100, duration: 0.01)
		# Measure the precision sleep using the monotonic clock:
		start_time = self.now
		repeats.times do
			sleep(duration)
		end
		end_time = self.now
		
		actual_duration = end_time - start_time
		expected_duration = repeats * duration
		
		if actual_duration < expected_duration
			warn "Invalid precision measurement: #{actual_duration} < #{expected_duration}"
			return 0.1
		end
		
		# This computes the overhead of sleep, called `repeats` times:
		return actual_duration - expected_duration
	end
	
	def now
		Process.clock_gettime(Process::CLOCK_MONOTONIC)
	end
end

Q = TIMER_QUANTUM = TimerQuantum.resolve
