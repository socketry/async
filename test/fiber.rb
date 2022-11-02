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
	end
end
