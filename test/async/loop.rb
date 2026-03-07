# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/loop"
require "sus/fixtures/console"

describe Async::Loop do
	include Sus::Fixtures::Console::CapturedLogger
	
	with ".quantized" do
		it "invokes the block at aligned intervals" do
			queue = Thread::Queue.new
			interval = 0.1
			
			thread = Thread.new do
				Async::Loop.quantized(interval: interval) do
					queue << Time.now.to_f
				end
			end
			
			# Collect at least 3 executions
			execution_times = []
			3.times do
				execution_times << queue.pop
			end
		ensure
			thread&.kill
			thread&.join
			
			expect(execution_times.size).to be >= 3
		end
		
		it "continues after an error and logs it" do
			queue = Thread::Queue.new
			interval = 0.05
			
			thread = Thread.new do
				iteration = 0
				Async::Loop.quantized(interval: interval) do
					iteration += 1
					queue << iteration
					raise "test error" if iteration == 1
				end
			end
			
			# Wait for first iteration (raises), then at least one more (succeeds)
			iterations = []
			3.times do
				iterations << queue.pop
			end
		ensure
			thread&.kill
			thread&.join
			
			expect(iterations).to be == [1, 2, 3]
			expect_console.to have_logged(
				severity: be == :error,
				subject: be_equal(Async::Loop),
				message: be =~ /Loop error:/
			)
		end
		
		it "aligns executions to interval boundaries" do
			queue = Thread::Queue.new
			interval = 0.1
			
			thread = Thread.new do
				Async::Loop.quantized(interval: interval) do
					queue << Time.now.to_f
				end
			end
			
			# Collect several executions
			execution_times = []
			5.times do
				execution_times << queue.pop
			end
		ensure
			thread&.kill
			thread&.join
			
			# Verify we got the expected number of executions
			expect(execution_times.size).to be == 5
		end
	end
	
	with ".periodic" do
		it "executes the block repeatedly with fixed delays" do
			queue = Thread::Queue.new
			interval = 0.05
			
			thread = Thread.new do
				Async::Loop.periodic(interval: interval) do
					queue << Time.now.to_f
				end
			end
			
			# Collect at least 3 executions
			execution_times = []
			3.times do
				execution_times << queue.pop
			end
		ensure
			thread&.kill
			thread&.join
			
			expect(execution_times.size).to be == 3
		end
		
		it "waits after each execution completes" do
			queue = Thread::Queue.new
			interval = 0.05
			
			thread = Thread.new do
				Async::Loop.periodic(interval: interval) do
					queue << Time.now.to_f
				end
			end
			
			# Collect several executions
			execution_times = []
			5.times do
				execution_times << queue.pop
			end
		ensure
			thread&.kill
			thread&.join
			
			# Check that there's at least 'interval' time between executions
			gaps = execution_times.each_cons(2).map{|a, b| b - a}
			
			gaps.each do |gap|
				expect(gap).to be >= interval
			end
		end
		
		it "continues after an error and logs it" do
			queue = Thread::Queue.new
			interval = 0.05
			
			thread = Thread.new do
				iteration = 0
				Async::Loop.periodic(interval: interval) do
					iteration += 1
					queue << iteration
					raise "periodic error" if iteration == 2
				end
			end
			
			# Collect iterations including the one that errors
			iterations = []
			4.times do
				iterations << queue.pop
			end
		ensure
			thread&.kill
			thread&.join
			
			expect(iterations).to be == [1, 2, 3, 4]
			expect_console.to have_logged(
				severity: be == :error,
				subject: be_equal(Async::Loop),
				message: be =~ /Loop error:/
			)
		end
		
		it "executes immediately on first iteration" do
			queue = Thread::Queue.new
			start_time = Time.now.to_f
			
			thread = Thread.new do
				Async::Loop.periodic(interval: 0.1) do
					queue << Time.now.to_f
				end
			end
			
			# Get the first execution time
			first_execution_time = queue.pop
		ensure
			thread&.kill
			thread&.join
			
			# The first execution should happen almost immediately
			elapsed = first_execution_time - start_time
			expect(elapsed).to be < 0.05
		end
		
		it "accounts for execution time in the interval" do
			queue = Thread::Queue.new
			execution_duration = 0.03
			interval = 0.05
			
			thread = Thread.new do
				Async::Loop.periodic(interval: interval) do
					queue << Time.now.to_f
					sleep(execution_duration)
				end
			end
			
			# Collect several executions
			execution_times = []
			4.times do
				execution_times << queue.pop
			end
		ensure
			thread&.kill
			thread&.join
			
			# Time between starts should be at least interval + execution_duration
			gaps = execution_times.each_cons(2).map{|a, b| b - a}
			expected_minimum = interval + execution_duration
			
			gaps.each do |gap|
				expect(gap).to be >= expected_minimum
			end
		end
	end
end
