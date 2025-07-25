# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2025, by Samuel Williams.

require "async"

describe Enumerator do
	def some_yielder(task)
		yield 1
		sleep(0.002)
		yield 2
	end
	
	def enum(task)
		to_enum(:some_yielder, task)
	end
	
	it "should play well with Enumerator as internal iterator" do
		# no fiber really used in internal iterator,
		# but let this test be here for completness
		result = nil
		
		Async do |task|
			result = enum(task).to_a
		end
		
		expect(result).to be == [1, 2]
	end
	
	it "should play well with Enumerator as external iterator" do
		result = []
		
		Async do |task|
			enumerator = enum(task)
			result << enumerator.next
			result << enumerator.next
			result << begin enumerator.next rescue $! end
		end
		
		expect(result[0]).to be == 1
		expect(result[1]).to be == 2
		expect(result[2]).to be_a StopIteration
	end
	
	it "should play well with Enumerator.zip(Enumerator) method" do
		Async do |task|
			result = [:a, :b, :c, :d].each.zip(enum(task))
			expect(result).to be == [[:a, 1], [:b, 2], [:c, nil], [:d, nil]]
		end
	end
	
	it "should play well with explicit Fiber usage" do
		result = []
		
		Async do |task|
			fiber = Fiber.new do
				Fiber.yield 1
				sleep(0.002)
				Fiber.yield 2
			end
			
			result << fiber.resume
			result << fiber.resume
			result << fiber.resume
		end
		
		expect(result[0]).to be == 1
		expect(result[1]).to be == 2
		expect(result[2]).to be == nil
	end
	
	it "can stop lazy enumerator" do
		# This test will hang on older Rubies without the bug fix:
		skip_unless_minimum_ruby_version("3.3.4")
		
		enumerator = Enumerator.new do |yielder|
			yielder.yield 1
			sleep
			yielder.yield 2
		end
		
		Sync do |task|
			child_task = task.async do
				enumerator.next
				enumerator.next
			end
			
			child_task.stop
			
			expect(child_task).to be(:stopped?)
		end
	end
end
