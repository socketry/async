# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "kernel/barrier"

describe Kernel do
	with "#Barrier" do
		it "should create a barrier, yield it, wait, and stop automatically" do
			finished = 0
			results = []
			
			Barrier do |barrier|
				3.times do |i|
					barrier.async do |task|
						sleep(0.01 * i)  # Different completion times
						results << "task_#{i}"
						finished += 1
					end
				end
			end
			
			expect(finished).to be == 3
			expect(results.size).to be == 3
		end
		
		it "should handle exceptions and still clean up properly" do
			exception_raised = false
			
			expect do
				Barrier do |barrier|
					barrier.async do |task|
						raise "Test exception"
					end
					
					barrier.async do |task|
						sleep(0.1)  # This should be stopped
					end
				end
			end.to raise_exception(RuntimeError, message: be =~ /Test exception/)
			
			# The barrier should have been cleaned up despite the exception.
		end
		
		it "should support parent parameter" do
			parent_task = nil
			child_task = nil
			
			Sync do |task|
				parent_task = task
				
				Barrier(parent: task) do |barrier|
					barrier.async do |async_task|
						child_task = async_task
						# While the child task is running, parent should be set:
						expect(child_task.parent).to be == parent_task
						sleep(0.01)
					end
				end
			end
			
			expect(child_task).not.to be_nil
		end
		
		it "should wait for all tasks to complete before returning" do
			completion_order = []
			
			Barrier do |barrier|
				3.times do |i|
					barrier.async do |task|
						sleep(0.01 * (3 - i))  # Reverse order completion
						completion_order << i
					end
				end
			end
			
			# All tasks should have completed
			expect(completion_order.size).to be == 3
			expect(completion_order.sort).to be == [0, 1, 2]
		end
		
		it "should stop remaining tasks when block exits early" do
			tasks = []

			Sync do |parent|
				begin
					Barrier do |barrier|
						3.times do |i|
							tasks << barrier.async do |task|
								sleep(1)  # Long running task
							end
						end
						
						# Simulate early exit due to some condition
						raise "Early exit"
					end
				rescue => e
					# Expected exception
				end

				# Wait for tasks to finish/stopped deterministically
				tasks.each do |t|
					begin
						t.wait
					rescue => e
						# ignore errors from waiting on stopped tasks
					end
				end
			end

			# All three tasks should have been stopped
			expect(tasks.map(&:stopped?).all?).to be == true
		end
		
		it "should handle empty barriers gracefully" do
			result = nil
			
			expect do
				result = Async::Barrier() do |barrier|
					# No tasks added
				end
			end.not.to raise_exception
			
			# Should complete successfully
		end
	end

	with "Kernel::Barrier" do
		it "should create a barrier, yield it, wait, and stop automatically" do
			finished = 0
			results = []
			Barrier() do |barrier|
				3.times do |i|
					barrier.async do |task|
						sleep(0.01 * i)
						results << "task_#{i}"
						finished += 1
					end
				end
			end

			expect(finished).to be == 3
			expect(results.size).to be == 3
		end

		it "should handle exceptions and still clean up properly" do
			expect do
				Barrier() do |barrier|
					barrier.async do |task|
						raise "Kernel helper exception"
					end
					barrier.async do |task|
						sleep(0.1)
					end
				end
			end.to raise_exception(RuntimeError, message: be =~ /Kernel helper exception/)
		end

		it "should support parent parameter" do
			parent_task = nil
			child_task = nil

			Sync do |task|
				parent_task = task

				Barrier(parent: task) do |barrier|
					barrier.async do |async_task|
						child_task = async_task
						# While the child task is running, parent should be set:
						expect(child_task.parent).to be == parent_task
						sleep(0.01)
					end
				end
			end

			expect(child_task).not.to be_nil
		end
	end
end
