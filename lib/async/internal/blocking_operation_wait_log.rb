# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

module Async
	module Internal
		class Sample
			def initialize(name)
				@name = name
				
				@count = 0
				@total = 0
			end
			
			def measure
				start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
				
				yield
			ensure
				finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)
				
				@count += 1
				@total += finish - start
			end
			
			def average
				@total / @count
			end
			
			def to_s
				"#{@name}: #{@count} samples, average: #{format_time(average)}"
			end
			
			private
			
			def format_time(time)
				if time < 1e-6
					"%.0fns" % (time * 1e9)
				elsif time < 1e-3
					"%.0fµs" % (time * 1e6)
				elsif time < 1
					"%.0fms" % (time * 1e3)
				else
					"%.3fs" % time
				end
			end
		end
		
		module BlockingOperationWaitLog
			def run(...)
				@blocking_operations = {}
				
				super
			ensure
				@blocking_operations.each do |name, sample|
					$stderr.puts sample
				end
				
				@blocking_operations = nil
			end
			
			def blocking_operation_wait(work)
				from = caller(1, 1).first
				
				sample = (@blocking_operations[from] ||= Sample.new(from))
				
				sample.measure do
					return super
				end
			end
		end
	end
end
