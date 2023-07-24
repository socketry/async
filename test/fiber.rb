# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/reactor'
require 'child_process'

describe Fiber do
	with '.schedule' do
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
		
		it 'correctly handles exceptions in process' do
			buffer = ChildProcess.spawn(<<~RUBY)
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
		
		it 'correctly handles exceptions' do
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
