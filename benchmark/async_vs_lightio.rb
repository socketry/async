#!/usr/bin/env ruby

require 'async'
require 'lightio'

require 'benchmark/ips'

def run_async(count = 10000)
	Async::Reactor.run do |task|
		tasks = count.times.map do
			# LightIO::Beam is a thread-like executor, use it instead Thread
			task.async do |subtask|
				# do some io operations in beam
				subtask.sleep(0.0001)
			end
		end
		
		tasks.each(&:wait)
	end
end

def run_lightio(count = 10000)
	beams = count.times.map do
		# LightIO::Beam is a thread-like executor, use it instead Thread
		LightIO::Beam.new do
			# do some io operations in beam
			LightIO.sleep(0.0001)
		end
	end

	beams.each(&:join)
end

Benchmark.ips do |benchmark|
	benchmark.report("lightio") do |count|
		run_lightio(count)
	end
	
	benchmark.report("async") do |count|
		run_async(count)
	end
	
	benchmark.compare!
end
