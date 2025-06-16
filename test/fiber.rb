# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.

require "async"
require "async/variable"

describe Fiber do
	with ".new" do
		it "can stop a task with a nested resumed fiber" do
			skip_unless_minimum_ruby_version("3.3.4")
			
			variable = Async::Variable.new
			error = nil
			
			Sync do |task|
				child_task = task.async do
					Fiber.new do
						# Wait here...
						variable.value
					rescue Async::Stop => error
						# This is expected.
						raise
					end.resume
				end
				
				child_task.stop
				expect(child_task).to be(:stopped?)
			end
			
			expect(error).to be_a(Async::Stop)
		end
		
		it "can nest child tasks within a resumed fiber" do
			skip_unless_minimum_ruby_version("3.3.4")
			
			variable = Async::Variable.new
			error = nil
			
			Sync do |task|
				child_task = task.async do
					Fiber.new do
						Async do
							variable.value
						end.wait
					end.resume
				end
				
				expect(child_task).to be(:running?)
				
				variable.value = true
			end
		end
	end
	
	with ".schedule" do
		it "can create several tasks" do
			sequence = []
			
			Thread.new do
				scheduler = Async::Scheduler.new
				Fiber.set_scheduler(scheduler)
				
				Fiber.schedule do
					3.times do |i|
						Fiber.schedule do
							sleep (i / 1000.0)
							sequence << i
						end
					end
				end
			end.join
			
			expect(sequence).to be == [0, 1, 2]
		end
		
		def spawn_child_ruby(code)
			lib_path = File.expand_path("../lib", __dir__)
			
			IO.popen(["ruby", "-I#{lib_path}"], "r+", err: [:child, :out]) do |process|
				process.write(code)
				process.close_write
				
				return process.read
			end
		end
		
		it "correctly handles exceptions in process" do
			buffer = spawn_child_ruby(<<~RUBY)
				require 'async'
				
				scheduler = Async::Scheduler.new
				Fiber.set_scheduler(scheduler)
				
				Fiber.schedule do
					sleep(1)
					puts "Finished sleeping!"
				end
				
				raise "Boom!"
			RUBY
			
			expect(buffer).to be(:include?, "Boom!")
			expect(buffer).not.to be(:include?, "Finished sleeping!")
		end
		
		it "correctly handles exceptions" do
			finished_sleeping = nil
			
			thread = Thread.new do
				# Stop the thread logging on exception:
				Thread.current.report_on_exception = false
				
				scheduler = Async::Scheduler.new
				Fiber.set_scheduler(scheduler)
				
				finished_sleeping = false
				
				Fiber.schedule do
					sleep(10)
					finished_sleeping = true
				end
				
				raise "Boom!"
			end
			
			expect{thread.join}.to raise_exception(RuntimeError,
				message: be == "Boom!"
			)
			
			expect(finished_sleeping).to be == false
		end
	end
end
