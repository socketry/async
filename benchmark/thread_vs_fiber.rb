#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.

require "benchmark/ips"

GC.disable

Benchmark.ips do |benchmark|
	benchmark.time = 1
	benchmark.warmup = 1
	
	benchmark.report("Thread.new{}") do |count|
		while count > 0
			Thread.new{count -= 1}.join
		end
	end
	
	benchmark.report("Fiber.new{}") do |count|
		while count > 0
			Fiber.new{count -= 1}.resume
		end
	end
	
	benchmark.compare!
end
