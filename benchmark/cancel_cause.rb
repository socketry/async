#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "async"

module CountCancelCauses
	attr_accessor :for_calls
	
	def for(*arguments, **options, &block)
		self.for_calls ||= 0
		self.for_calls += 1
		
		super(*arguments, **options, &block)
	end
end

Async::Cancel::Cause.singleton_class.prepend(CountCancelCauses)

def positive_integer(name, default)
	Integer(ENV.fetch(name, default)).tap do |value|
		abort("#{name} must be positive!") unless value.positive?
	end
end

def measure_cancel(total_tasks)
	scheduler = Async::Scheduler.new
	ready = Thread::Queue.new
	
	Fiber.set_scheduler(scheduler)
	
	begin
		total_tasks.times do
			scheduler.async do
				ready.push(true)
				sleep
			end
		end
		
		total_tasks.times do
			ready.pop
		end
		
		GC.start
		Async::Cancel::Cause.for_calls = 0
		
		# Measure the synchronous fan-out only; draining cancelled tasks happens in `ensure`.
		allocated_before = GC.stat(:total_allocated_objects)
		start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
		
		scheduler.cancel
		
		duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
		allocated_after = GC.stat(:total_allocated_objects)
		
		return {
			tasks: total_tasks,
			cause_for_calls: Async::Cancel::Cause.for_calls,
			allocated_objects: allocated_after - allocated_before,
			duration_ms: duration * 1000.0
		}
	ensure
		scheduler.run unless scheduler.closed?
		Fiber.set_scheduler(nil)
	end
end

tasks = positive_integer("TASKS", 1365)

result = measure_cancel(tasks)

puts "tasks=#{result.fetch(:tasks)}"
puts "cause_for_calls=#{result.fetch(:cause_for_calls)}"
puts "allocated_objects=#{result.fetch(:allocated_objects)}"
puts "duration_ms=#{format('%.2f', result.fetch(:duration_ms))}"
