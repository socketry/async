#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/benchmark"
require "async"

describe Async::Task do
	include Sus::Fixtures::Benchmark
	
	with "task creation and execution" do
		measure "simple task creation and completion" do |repeats|
			Async do |task|
				repeats.times do
					child = task.async {"result"}
					child.wait
				end
			end
		end
		
		measure "task creation with arguments" do |repeats|
			Async do |task|
				repeats.times do
					child = task.async(42) do |task, value|
						value * 2
					end
					child.wait
				end
			end
		end
		
		measure "nested task creation" do |repeats|
			Async do |task|
				repeats.times do
					parent = task.async do |parent_task|
						child = parent_task.async do
							"nested result"
						end
						child.wait
					end
					parent.wait
				end
			end
		end
	end
	
	with "wait operations" do
		measure "wait on immediately completing tasks" do |repeats|
			Async do |task|
				repeats.times do
					child = task.async {"result"}
					child.wait
				end
			end
		end
		
		measure "wait on delayed tasks" do |repeats|
			Async do |task|
				repeats.times do
					child = task.async do
						sleep(0.001)
						"result"
					end
					child.wait
				end
			end
		end
		
		measure "wait on already completed tasks" do |repeats|
			# Pre-create completed tasks
			completed_tasks = []
			Async do |task|
				100.times do
					completed_tasks << task.async {"completed"}
				end
				
				# Wait for all to complete
				completed_tasks.each(&:wait)
			end
			
			# Measure waiting on already completed tasks
			task_index = 0
			repeats.times do
				completed_tasks[task_index].wait
				task_index = (task_index + 1) % completed_tasks.size
			end
		end
	end
	
	with "concurrent operations" do
		measure "parent waiting on multiple children" do |repeats|
			Async do |task|
				repeats.times do
					# Create multiple child tasks
					children = 4.times.map do |i|
						task.async do
							sleep(0.001)
							"child-#{i}"
						end
					end
					
					# Wait for all children
					children.map(&:wait)
				end
			end
		end
		
		measure "sequential task dependency chain" do |repeats|
			Async do |task|
				# Create a chain of tasks where each waits for the previous
				previous_task = nil
				
				task_counter = 0
				repeats.times do
					current_task = task.async do
						previous_task&.wait
						"task-#{task_counter}"
					end
					previous_task = current_task
					task_counter += 1
				end
				
				# Wait for the final task (which waits for all previous)
				previous_task.wait
			end
		end
	end
	
	with "exception handling" do
		measure "task failures and exception propagation" do |repeats|
			Async do |task|
				error_counter = 0
				repeats.times do
					failing_task = task.async do
						sleep(0.001)
						raise RuntimeError, "error-#{error_counter}"
					end
					
					begin
						failing_task.wait
					rescue RuntimeError
						# Expected exception, continue
					end
					
					error_counter += 1
				end
			end
		end
		
		measure "task stopping and cleanup" do |repeats|
			Async do |task|
				repeats.times do
					child = task.async do
						sleep(10) # Long running task
						"should be stopped"
					end
					
					# Immediately stop the task
					child.stop
					
					# Wait for it to be stopped (should be quick)
					begin
						child.wait
					rescue
						# Task was stopped, continue
					end
				end
			end
		end
	end
	
	with "memory and lifecycle" do
		measure "task lifecycle completion" do |repeats|
			Async do |task|
				result_counter = 0
				repeats.times do
					# Create task, run it, wait for completion
					child = task.async do
						"result-#{result_counter}"
					end
					
					child.wait
					# Task should be finished and cleaned up
					result_counter += 1
				end
			end
		end
		
		measure "task annotation and metadata" do |repeats|
			Async do |task|
				annotation_counter = 0
				repeats.times do
					child = task.async(annotation: "Task #{annotation_counter}") do
						# Check annotation access performance
						task.annotation
					end
					child.wait
					annotation_counter += 1
				end
			end
		end
	end
end
