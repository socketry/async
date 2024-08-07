#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Patrik Wenger.

require 'benchmark/ips'

GC.disable

Fiber.attr_accessor :foo

module FiberWithBar
	refine Fiber do
		attr_accessor :bar
	end
end

using FiberWithBar

Benchmark.ips do |benchmark|
	benchmark.time = 1
	benchmark.warmup = 1
	
	benchmark.report("monkey patch") do |count|
		while count > 0
			Fiber.new do
				count -= 1

				Fiber.current.foo = :baz
				fail if Fiber.current.foo != :baz
			end.resume
		end
	end
	
	benchmark.report("refinement") do |count|
		while count > 0
			Fiber.new do
				count -= 1

				Fiber.current.bar = :baz
				fail if Fiber.current.bar != :baz
			end.resume
		end
	end
	
	benchmark.compare!
end
