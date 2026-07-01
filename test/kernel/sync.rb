# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2025, by Samuel Williams.
# Copyright, 2020, by Brian Morearty.
# Copyright, 2024, by Patrik Wenger.

require "kernel/async"
require "kernel/sync"
require "async/barrier"
require "async/semaphore"

describe Kernel do
	with "#Sync" do
		let(:value) {10}
		
		it "can run a synchronous task" do
			result = Sync do |task|
				expect(Async::Task.current).not.to be == nil
				expect(Async::Task.current).to be == task
				
				next value
			end
			
			expect(result).to be == value
		end
		
		it "passes annotation through to initial task" do
			Sync(annotation: "foobar") do |task|
				expect(task.annotation).to be == "foobar"
			end
		end
		
		it "can run inside reactor" do
			Async do |task|
				result = Sync do |sync_task|
					expect(Async::Task.current).to be == task
					expect(sync_task).to be == task
					
					next value
				end
				
				expect(result).to be == value
			end
		end
		
		with "a non-blocking fiber" do
			it "can run the scheduler on a non-blocking fiber" do
				executed = false
				
				Fiber.new do
					Sync do |task|
						executed = true
					end
				end.resume
				
				expect(executed).to be == true
			end
			
			it "returns the result of the block" do
				result = Fiber.new do
					Sync{|task| value}
				end.resume
				
				expect(result).to be == value
			end
			
			it "can run asynchronous work with blocking operations" do
				result = Fiber.new do
					Sync do |task|
						barrier = Async::Barrier.new
						semaphore = Async::Semaphore.new(2, parent: barrier)
						
						results = (1..4).map do |index|
							semaphore.async{sleep(0.001); index}
						end.map(&:wait)
						
						barrier.stop
						
						results
					end
				end.resume
				
				expect(result).to be == [1, 2, 3, 4]
			end
			
			it "propagates exceptions raised in the block" do
				expect do
					Fiber.new do
						Sync do |task|
							raise StandardError, "boom"
						end
					end.resume
				end.to raise_exception(StandardError, message: be =~ /boom/)
			end
			
			it "runs on the calling fiber, preserving fiber storage" do
				Fiber[:annotation] = "outer"
				
				result = Fiber.new do
					Sync{|task| Fiber[:annotation]}
				end.resume
				
				expect(result).to be == "outer"
			end
			
			it "supports nested synchronous tasks" do
				result = Fiber.new do
					Sync do |outer|
						Sync do |inner|
							expect(inner).to be_equal(outer)
							value
						end
					end
				end.resume
				
				expect(result).to be == value
			end
			
			it "can be used from within an Enumerator" do
				# The value is yielded *after* `Sync` returns, so the yield happens on the enumerator fiber:
				enumerator = Enumerator.new do |yielder|
					yielder << Sync{|task| value}
					yielder << Sync{|task| value * 2}
				end
				
				expect(enumerator.next).to be == value
				expect(enumerator.next).to be == value * 2
			end
			
			it "cannot yield to the enumerator from within the block" do
				# Yielding to the enumerator's consumer from inside `Sync` happens on the task fiber, which is not resumable, so it fails cleanly rather than hanging:
				enumerator = Enumerator.new do |yielder|
					Sync{yielder << value}
				end
				
				expect do
					enumerator.next
				end.to raise_exception(FiberError)
			end
			
			it "returns control to the scheduler when the loop fiber is entered via transfer" do
				# The reactor loop fiber may be entered via `Fiber#transfer` (e.g. owned
				# by another transfer-based scheduler), which places it off the resume
				# chain. When a task terminates, control must return to the loop fiber so
				# the reactor can finish - not to the resume-chain root. Without this,
				# the reactor is abandoned and the scenario deadlocks, so we run it in a
				# separate thread with a timeout:
				completed = nil
				
				thread = Thread.new do
					driver = worker = nil
					
					worker = Fiber.new do
						completed = Sync do |task|
							task.async{sleep(0.001)}.wait
							value
						end
						
						driver.transfer
					end
					
					driver = Fiber.new do
						# Enter the loop fiber via transfer, so it is off the resume chain:
						worker.transfer
					end
					
					driver.resume
				end
				
				finished = thread.join(2)
				thread.kill unless finished
				
				expect(finished).not.to be_nil
				expect(completed).to be == value
			end
		end
		
		it "cannot be worked around by running the scheduler on a nested blocking fiber" do
			# A tempting workaround is to force a blocking fiber before calling `Sync`:
			#
			#   Fiber.new(blocking: true){Sync(&block)}.resume
			#
			# But this is broken: the async scheduler moves between task fibers using `Fiber#transfer`, and per https://bugs.ruby-lang.org/issues/20081 a fiber entered via `resume` that unwinds through `transfer` returns control to the main fiber rather than the resuming fiber. When the enclosing fiber is already owned by a scheduler, the event loop can never hand control back and the whole thing deadlocks.
			def sync_on_blocking_fiber(&block)
				return Sync(&block) if Fiber.blocking? || Async::Task.current?
				
				Fiber.new(blocking: true){Sync(&block)}.resume
			end
			
			completed = false
			
			thread = Thread.new do
				Thread.current.report_on_exception = false
				
				Async do
					# Simulate a non-blocking fiber owned by some other framework (e.g. a job runner):
					Fiber.new do
						sync_on_blocking_fiber do |task|
							# The nested reactor suspends this task, which requires the scheduler to transfer control:
							task.async{sleep(0.001)}.wait
						end
					end.resume
				end
				
				completed = true
			end
			
			# The workaround deadlocks, so the thread never finishes:
			finished = thread.join(2)
			thread.kill unless finished
			
			expect(finished).to be_nil
			expect(completed).to be == false
		end
		
		with "parent task" do
			it "replaces and restores existing task's annotation" do
				annotations = []
				
				Async(annotation: "foo") do |t1|
					annotations << t1.annotation
					
					Sync(annotation: "bar") do |t2|
						expect(t2).to be_equal(t1)
						annotations << t1.annotation
					end
					
					annotations << t1.annotation
				end.wait
				
				expect(annotations).to be == %w[foo bar foo]
			end
		end
		
		it "can propagate error without logging them" do
			expect do
				Sync do |task|
					expect(task).not.to receive(:warn)
					
					raise StandardError, "brain not provided"
				end
			end.to raise_exception(StandardError, message: be =~ /brain/)
		end
		
		it "handles interrupts during initial task startup using the scheduler" do
			interrupted = false
			
			expect do
				Sync do |task|
					begin
						Thread.current.raise Interrupt
						task.async{}
					rescue Interrupt
						interrupted = true
						raise
					end
				end
			end.to raise_exception(Interrupt)
			
			expect(interrupted).to be == false
		end
		
		it "does not retry initial task startup after an interrupt" do
			attempts = 0
			
			expect do
				Sync do
					attempts += 1
					
					raise "Initial task startup retried." if attempts > 1
					
					raise Interrupt
				end
			end.to raise_exception(Interrupt)
			
			expect(attempts).to be == 1
		end
	end
end
