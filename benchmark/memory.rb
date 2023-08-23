#!/usr/bin/env ruby

# require "benchmark/memory"

# Benchmark.memory do |benchmark|
# 	benchmark.report("Thread.new{}") do
# 		Thread.new{true}.join
# 	end
	
# 	benchmark.report("Fiber.new{}") do
# 		Fiber.new{true}.resume
# 	end
	
# 	benchmark.compare!
# end

require 'memory'

report = Memory.report do
	Thread.new{true}.join
	Fiber.new{true}.resume
end

report.print