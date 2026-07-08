# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2025, by Samuel Williams.

require "sus/fixtures/async"
require "async/reactor"
require "async/barrier"
require "net/http"

require "sus/fixtures/console"

describe Async::Scheduler do
	include Sus::Fixtures::Console::CapturedLogger
	
	it "is supported" do
		expect(Async::Scheduler).to be(:supported?)
	end
	
	describe "Fiber.schedule" do
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
	
	with "#run_once" do
		it "can run the scheduler with a specific timeout" do
			scheduler = Async::Scheduler.new
			Fiber.set_scheduler(scheduler)
			
			task = scheduler.async do |task|
				sleep 1
			end
			
			expect do
				scheduler.run_once(0.001)
			end.to have_duration(be <= 0.1)
			
			expect(task).to be(:running?)
			task.stop
		ensure
			Fiber.set_scheduler(nil)
		end
	end
	
	with "#load" do
		it "normalizes load over a one second window" do
			scheduler = Async::Scheduler.new

			scheduler.instance_variable_set(:@busy_time, 2.0)
			scheduler.instance_variable_set(:@idle_time, 2.0)

			expect(scheduler.load).to be == 0.5
		ensure
			scheduler&.close
		end
	end

	with "#close" do
		it "runs the event loop until terminated" do
			scheduler = Async::Scheduler.new
			Async::Node.new(scheduler)

			terminations = 0
			scheduler.define_singleton_method(:terminate) do
				terminations += 1
				terminations > 1
			end

			runs = 0
			scheduler.define_singleton_method(:run_once!) do
				runs += 1
			end

			scheduler.close

			expect(runs).to be == 1
		end
	end

	if Async::Scheduler.method_defined?(:io_read)
		with "#io_read" do
			it "raises IO timeout errors when reads time out" do
				skip_unless_constant_defined(:TimeoutError, IO)

				scheduler = Async::Scheduler.new

				io = Object.new
				io.define_singleton_method(:timeout) {0}

				selector = Object.new
				selector.define_singleton_method(:io_read) do |fiber, io, buffer, length, offset|
					scheduler.instance_variable_get(:@timers).fire
				end
				selector.define_singleton_method(:close) {}

				scheduler.instance_variable_set(:@selector, selector)

				expect do
					scheduler.io_read(io, IO::Buffer.new(1024), 1024)
				end.to raise_exception(::IO::TimeoutError)
			ensure
				scheduler&.close
			end
		end
	end

	with "#cancel" do
		it "shares the generated cancellation cause with child tasks" do
			cause = Async::Cancel::Cause.new("Cancelling task!")
			child_errors = []
			
			scheduler = Async::Scheduler.new
			Fiber.set_scheduler(scheduler)
			
			expect(Async::Cancel::Cause).to receive(:for).with("Cancelling task!").and_return(cause)
			
			2.times do
				scheduler.async do
					begin
						sleep
					rescue Async::Cancel => error
						child_errors << error
						raise
					end
				end
			end
			
			scheduler.cancel
			scheduler.run
			
			expect(child_errors.size).to be == 2
			expect(child_errors).to be(:all?) do |error|
				error.cause.equal?(cause)
			end
		ensure
			Fiber.set_scheduler(nil)
		end
	end
	
	with "#interrupt" do
		it "can interrupt a scheduler while it's not running" do
			scheduler = Async::Scheduler.new
			finished = false
			
			scheduler.run do |task|
				# Interrupting here should mean that the yield below never returns:
				scheduler.interrupt
				
				scheduler.yield
				finished = true
			end
			
			expect(finished).to be == false
		end
		
		it "can interrupt a closed scheduler" do
			scheduler = Async::Scheduler.new
			scheduler.close
			scheduler.interrupt
		end
		
		it "can interrupt a scheduler from a different thread" do
			finished = false
			interrupted = false
			sleeping = Thread::Queue.new
			
			thread = Thread.new do
				scheduler = Async::Scheduler.new
				Fiber.set_scheduler(scheduler)
				
				scheduler.run do |task|
					sleeping.push(true)
					sleep
				ensure
					begin
						sleeping.push(true)
						sleep
					ensure
						finished = true
					end
				end
			rescue Interrupt
				interrupted = true
			end
			
			expect(sleeping.pop).to be == true
			expect(finished).to be == false
			expect(interrupted).to be == false
			
			thread.raise(Interrupt)
			
			expect(sleeping.pop).to be == true
			expect(finished).to be == false
			
			thread.raise(Interrupt)
			thread.join
			
			expect(finished).to be == true
			expect(interrupted).to be == true
		end
		
		it "ignores interrupts during termination" do
			sleeping = Thread::Queue.new
			
			thread = Thread.new do
				Thread.current.report_on_exception = false
				
				scheduler = Async::Scheduler.new
				Fiber.set_scheduler(scheduler)
				
				scheduler.run do |task|
					2.times do
						task.async do
							sleeping.push(true)
							sleep
						ensure
							sleeping.push(true)
							sleep
						end
					end
				end
			end
			
			# The first interrupt stops the tasks normally, but they enter sleep again:
			expect(sleeping.pop).to be == true
			thread.raise(Interrupt)
			
			# The second stop forcefully stops the two children tasks of the selector:
			expect(sleeping.pop).to be == true
			thread.raise(Interrupt)
			
			# The thread should now exit:
			begin
				thread.join
			rescue Interrupt
				# Ignore - this may happen:
				# https://github.com/ruby/ruby/pull/10039
			end
		end
	end
	
	with "#block" do
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
	
	with "transient tasks" do
		it "exits gracefully" do
			state = nil
			child_task = nil
			
			Sync do |task|
				child_task = task.async(transient: true) do
					state = :sleeping
					# Never come back:
					Fiber.scheduler.transfer
				ensure
					state = :ensure
					# Yoyo but eventually exit:
					5.times do
						Fiber.scheduler.yield
					end
					
					state = :finished
				end
			end
			
			expect(state).to be == :finished
			expect(child_task).not.to be(:transient?)
		end
	end
	
	it "prints out the stack trace of the scheduler" do
		ready = Thread::Queue.new
		thread = Thread.current
		
		scheduler = Async::Scheduler.new
		
		# This will interrupt the scheduler once it's running:
		Thread.new do
			ready.pop
			thread.raise(Interrupt)
		end
		
		expect do
			begin
				Fiber.set_scheduler(scheduler)
				
				scheduler.run do
					while true
						sleep(0)
						ready.push(true)
					end
				end
			ensure
				Fiber.set_scheduler(nil)
			end
		end.to raise_exception(Interrupt)
		
		expect_console.to have_logged(
			severity: be == :debug,
			subject: be == scheduler,
			message: be =~ /Scheduler interrupted/,
		)
	end
end
