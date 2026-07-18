# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2024, by Patrik Wenger.
# Copyright, 2026, by Shopify Inc.

require "kernel/async"

describe Kernel do
	describe ".Async" do
		it "can run an asynchronous task" do
			Async do |task|
				expect(task).to be_a Async::Task
			end
		end
		
		it "passes transient: options through to initial task" do
			Async(transient: true) do |task|
				expect(task).to be(:transient?)
			end
		end
		
		it "passes annotation: option through to initial task" do
			Async(annotation: "foobar") do |task|
				expect(task.annotation).to be == "foobar"
			end
		end
		
		with "a non-blocking fiber" do
			it "can run an asynchronous task on a non-blocking fiber" do
				task = nil
				
				Fiber.new do
					task = Async do |task|
						expect(task).to be_a(Async::Task)
					end
				end.resume
				
				expect(task).to be_a(Async::Task)
			end
			
			it "runs asynchronous work to completion on a non-blocking fiber" do
				executed = false
				
				Fiber.new do
					Async do |task|
						task.async{sleep(0.001); executed = true}.wait
					end
				end.resume
				
				expect(executed).to be == true
			end
			
			it "passes options through to the initial task on a non-blocking fiber" do
				annotation = nil
				
				Fiber.new do
					Async(annotation: "foobar") do |task|
						annotation = task.annotation
					end
				end.resume
				
				expect(annotation).to be == "foobar"
			end
		end
	end
end
