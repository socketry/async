#!/usr/bin/env ruby

require 'async'
require 'lightio'

require 'benchmark/ips'

#
# It's hard to know exactly how to interpret these results. When running parallel
# instances, resource contention is more likely to be a problem, and yet with
# async, the performance between a single task and several tasks is roughly the
# same, while in the case of lightio, there is an obvious performance gap.
# 
# The main takeaway is that contention causes issues and if systems are not
# designed with that in mind, it will impact performance.
#
# $ ruby async_vs_lightio.rb
# Warming up --------------------------------------
# lightio (synchronous)
#                          2.439k i/100ms
#  async (synchronous)     2.115k i/100ms
#   lightio (parallel)   211.000  i/100ms
#     async (parallel)   449.000  i/100ms
# Calculating -------------------------------------
# lightio (synchronous)
#                          64.502k (± 3.9%) i/s -    643.896k in  10.002151s
#  async (synchronous)    161.195k (± 1.6%) i/s -      1.612M in  10.000976s
#   lightio (parallel)     49.827k (±17.5%) i/s -    477.704k in   9.999579s
#     async (parallel)    166.862k (± 6.2%) i/s -      1.662M in  10.000365s
# 
# Comparison:
#     async (parallel):   166862.3 i/s
#  async (synchronous):   161194.6 i/s - same-ish: difference falls within error
# lightio (synchronous):   64502.5 i/s - 2.59x  slower
#   lightio (parallel):    49827.3 i/s - 3.35x  slower


DURATION = 0.000001

def run_async(count, repeats = 10000)
	Async::Reactor.run do |task|
		count.times.map do
			task.async do |subtask|
				repeats.times do
					subtask.sleep(DURATION)
				end
			end
		end.each(&:wait)
	end
end

def run_lightio(count, repeats = 10000)
	count.times.map do
		LightIO::Beam.new do
			repeats.times do
				LightIO.sleep(DURATION)
			end
		end
	end.each(&:join)
end

Benchmark.ips do |benchmark|
	benchmark.time = 10
	benchmark.warmup = 2
	
	benchmark.report("lightio (synchronous)") do |count|
		run_lightio(1, count)
	end
	
	benchmark.report("async (synchronous)") do |count|
		run_async(1, count)
	end
	
	benchmark.report("lightio (parallel)") do |count|
		run_lightio(32, count/32)
	end
	
	benchmark.report("async (parallel)") do |count|
		run_async(32, count/32)
	end
	
	benchmark.compare!
end
