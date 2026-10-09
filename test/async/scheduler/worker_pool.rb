# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async"

describe Async::Scheduler do
	def around
		worker_pool = Async::Scheduler.worker_pool
		
		super
	ensure
		Async::Scheduler.worker_pool = worker_pool
	end
	
	# Run a blocking operation in a new reactor, and return the reactor's worker pool.
	def sync_worker_pool
		Sync do
			worker_pool = Fiber.scheduler.instance_variable_get(:@worker_pool)
			
			if worker_pool
				expect(IO::Event::WorkerPool.busy(duration: 0.001)).to have_keys(result: be == :completed)
			end
			
			worker_pool
		end
	end
	
	with ".worker_pool" do
		it "defaults to the environment variable" do
			if ENV["ASYNC_SCHEDULER_WORKER_POOL"] == "true"
				expect(Async::Scheduler::WORKER_POOL).to be == true
				expect(Async::Scheduler.worker_pool).to be == Async::Scheduler::WorkerPool&.method(:new)
			else
				expect(Async::Scheduler::WORKER_POOL).to be_nil
				expect(Async::Scheduler.worker_pool).to be_nil
			end
		end
		
		it "can be set to a factory" do
			factory = proc{nil}
			Async::Scheduler.worker_pool = factory
			
			expect(Async::Scheduler.worker_pool).to be_equal(factory)
		end
		
		it "can be disabled" do
			Async::Scheduler.worker_pool = proc{nil}
			Async::Scheduler.worker_pool = nil
			
			expect(Async::Scheduler.worker_pool).to be_nil
		end
		
		it "is shared with subclasses" do
			factory = proc{nil}
			Async::Reactor.worker_pool = factory
			
			expect(Async::Scheduler.worker_pool).to be_equal(factory)
		end
		
		it "can't be a worker pool instance" do
			skip_unless_constant_defined(:WorkerPool, IO::Event)
			
			worker_pool = IO::Event::WorkerPool.new
			
			expect do
				Async::Scheduler.worker_pool = worker_pool
			end.to raise_exception(ArgumentError, message: be =~ /can't be shared/)
		ensure
			worker_pool&.close
		end
		
		it "can't be a boolean" do
			expect do
				Async::Scheduler.worker_pool = true
			end.to raise_exception(ArgumentError, message: be =~ /must be callable/)
		end
	end
	
	with ".enable_worker_pool" do
		it "sets the default factory" do
			Async::Scheduler.worker_pool = nil
			Async::Scheduler.enable_worker_pool
			
			expect(Async::Scheduler.worker_pool).to be == Async::Scheduler::WorkerPool&.method(:new)
		end
	end
	
	with "worker pool" do
		def before
			skip_unless_constant_defined(:WorkerPool, IO::Event)
			
			super
		end
		
		it "is enabled for schedulers created by Sync" do
			Async::Scheduler.enable_worker_pool
			
			Sync do
				expect(Fiber.scheduler).to respond_to(:blocking_operation_wait)
			end
			
			worker_pool = sync_worker_pool
			expect(worker_pool).to be_a(IO::Event::WorkerPool)
			expect(worker_pool.statistics).to have_keys(
				call_count: be > 0,
				shutdown: be == true,
			)
		end
		
		it "is disabled for schedulers created by Sync" do
			Async::Scheduler.worker_pool = nil
			
			Sync do
				expect(Fiber.scheduler).not.to respond_to(:blocking_operation_wait)
			end
			
			expect(sync_worker_pool).to be_nil
		end
		
		it "creates a new worker pool for each scheduler" do
			Async::Scheduler.enable_worker_pool
			
			first = sync_worker_pool
			second = sync_worker_pool
			
			expect(first).to be_a(IO::Event::WorkerPool)
			expect(second).to be_a(IO::Event::WorkerPool)
			expect(second).not.to be_equal(first)
			
			expect(first.statistics).to have_keys(call_count: be == 1)
			expect(second.statistics).to have_keys(call_count: be == 1)
		end
		
		it "can use a callable to create each worker pool" do
			calls = 0
			
			Async::Scheduler.worker_pool = proc do
				calls += 1
				IO::Event::WorkerPool.new(maximum_worker_count: 2)
			end
			
			first = sync_worker_pool
			second = sync_worker_pool
			
			expect(calls).to be == 2
			expect(second).not.to be_equal(first)
			expect(first.statistics).to have_keys(maximum_worker_count: be == 2, call_count: be == 1)
			expect(second.statistics).to have_keys(maximum_worker_count: be == 2, call_count: be == 1)
		end
		
		with "explicit worker_pool:" do
			it "can disable the worker pool" do
				Async::Scheduler.enable_worker_pool
				
				scheduler = Async::Scheduler.new(worker_pool: nil)
				
				expect(scheduler).not.to respond_to(:blocking_operation_wait)
			ensure
				scheduler&.close
			end
			
			it "can enable the worker pool" do
				Async::Scheduler.worker_pool = nil
				
				scheduler = Async::Scheduler.new(worker_pool: true)
				
				expect(scheduler).to respond_to(:blocking_operation_wait)
			ensure
				scheduler&.close
			end
			
			it "can use a specific worker pool" do
				Async::Scheduler.worker_pool = proc{raise "Should not be called!"}
				
				worker_pool = IO::Event::WorkerPool.new
				scheduler = Async::Scheduler.new(worker_pool: worker_pool)
				
				expect(scheduler.instance_variable_get(:@worker_pool)).to be_equal(worker_pool)
			ensure
				scheduler&.close
			end
		end
	end
end
