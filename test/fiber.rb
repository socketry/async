# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/reactor'

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
			path = File.expand_path(".fiber/error.rb", __dir__)
			process = IO.popen(path, err: [:child, :out])
			buffer = process.read
			
			expect(buffer).to be(:include?, "Boom!")
			expect(buffer).not.to be(:include?, "Finished sleeping!")
		ensure
			process&.close
		end
		
		it 'correctly handles exceptions' do
			finished_sleeping = nil
			
			thread = Thread.new do
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
