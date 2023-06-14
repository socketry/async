# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2023, by Samuel Williams.

require 'sus/fixtures/async'
require 'async/reactor'
require 'async/barrier'
require 'net/http'

describe Async::Scheduler do
	it "is supported" do
		expect(Async::Scheduler).to be(:supported?)
	end
	
	describe 'Fiber.schedule' do
		it "can start child task" do
			fiber = nil
			
			Async do
				Fiber.schedule do
					fiber = Fiber.current
				end
			end.wait
			
			expect(fiber).not.to be_nil
			expect(fiber).to be_a(Fiber)
		end
		
		it "can schedule task before starting scheduler" do
			sequence = []
			
			thread = Thread.new do
				scheduler = Async::Scheduler.new
				
				scheduler.async do
					sequence << :running
				end
				
				Fiber.set_scheduler(scheduler)
			end
			
			thread.join
			
			expect(sequence).to be == [:running]
		end
	end
	
	with '#run_once' do
		it "can run the scheduler with a specific timeout" do
			scheduler = Async::Scheduler.new
			Fiber.set_scheduler(scheduler)
			
			task = scheduler.async do |task|
				sleep 1
			end
			
			duration = Async::Clock.measure do
				scheduler.run_once(0.001)
			end
			
			expect(task).to be(:running?)
			expect(duration).to be <= 0.1
		end
	end
	
	with '#interrupt' do
		it "can interrupt a closed scheduler" do
			scheduler = Async::Scheduler.new
			scheduler.close
			scheduler.interrupt
		end
	end
	
	with '#block' do
		it "can block and unblock the scheduler after closing" do
			scheduler = Async::Scheduler.new
			
			fiber = Fiber.new do
				scheduler.block(:test, nil)
			end
			
			fiber.transfer
			
			expect do
				scheduler.close
			end.to raise_exception(RuntimeError, message: be =~ /Closing scheduler with blocked operations/)
		end
	end
end
