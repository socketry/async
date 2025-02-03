# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.
# Copyright, 2024, by Patrik Wenger.

require "async/internal/worker_pool"
require "sus/fixtures/async"

describe Async::Internal::WorkerPool do
	let(:worker_pool) {subject.new(size: 1)}
	
	it "offloads work to a thread" do
		result = worker_pool.call(proc do
			Thread.current
		end)
		
		expect(result).not.to be == Thread.current
	end
	
	it "gracefully handles errors" do
		expect do
			worker_pool.call(proc do
				raise ArgumentError, "Oops!"
			end)
		end.to raise_exception(ArgumentError, message: be == "Oops!")
	end
	
	it "can cancel work" do
		sleeping = ::Thread::Queue.new
		
		thread = Thread.new do
			Thread.current.report_on_exception = false
			
			worker_pool.call(proc do
				sleeping.push(true)
				sleep(1)
			end)
		end
		
		# Wait for the worker to start:
		sleeping.pop
		
		thread.raise(Interrupt)
		
		expect do
			thread.join
		end.to raise_exception(Interrupt)
	end
	
	with "#close" do
		it "can be closed" do
			worker_pool.close
			
			expect do
				worker_pool.call(proc{})
			end.to raise_exception(RuntimeError)
		end
	end
end
