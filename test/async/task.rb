# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.

require 'async'
require 'async/clock'
require 'async/queue'

require 'timer_quantum'

describe Async::Task do
	let(:reactor) {Async::Reactor.new}
	
	describe '.yield' do
		it "can yield back to scheduler" do
			state = nil
			
			reactor.async do |task|
				child = task.async do
					state = :yielding
					Async::Task.yield
					state = :yielded
				end
				
				Fiber.scheduler.resume(child.fiber)
			end
			
			reactor.run
			
			expect(state).to be == :yielded
		end
	end
	
	with '#run' do
		it "can't be invoked twice" do
			task = reactor.async do |task|
			end
			
			expect{task.run}.to raise_exception(RuntimeError, message: be =~ /already running/)
		end
	end
	
	with '#current?' do
		it "can check if it is the currently running task" do
			task = reactor.async do |task|
				expect(task).to be(:current?)
				task.sleep(0.1)
			end
			
			expect(task).not.to be(:current?)
		end
	end
	
	with '#async' do
		it "can start child async tasks" do
			parent = reactor.async do |task|
				child = task.async do
					task.sleep(1)
				end
				
				expect(child).not.to be_nil
				expect(child.parent).not.to be_nil
			ensure
				child.stop
			end
			
			expect(parent).not.to be_nil
			
			reactor.run
		end
		
		it "can pass in arguments" do
			reactor.async do |task|
				task.async(:arg) do |task, arg|
					expect(arg).to be == :arg
				end
			end
			
			reactor.run
		end
		
		it "can set initial annotation" do
			reactor.async(annotation: "Hello World") do |task|
				expect(task.annotation).to be == "Hello World"
			end
			
			reactor.run
		end
		
		it "can raise exceptions" do
			reactor.run do
				expect do
					reactor.async do |task|
						raise "boom"
					end.wait
				end.to raise_exception(RuntimeError, message: be =~ /boom/)
			end
		end
		
		it "can raise exception after asynchronous operation" do
			task = nil
			
			expect do
				task = reactor.async do |task|
					task.sleep 0.1
					
					raise "boom"
				end
			end.not.to raise_exception
			
			reactor.run do
				expect do
					task.wait
				end.to raise_exception(RuntimeError, message: be =~ /boom/)
			end
		end
		
		it "can consume exceptions" do
			task = nil
			
			expect do
				task = reactor.async do |task|
					raise "boom"
				end
			end.not.to raise_exception
			
			reactor.run do
				expect do
					task.wait
				end.to raise_exception(RuntimeError, message: be =~ /boom/)
			end
		end
		
		it "won't consume non-StandardError exceptions" do
			expect do
				reactor.run do
					reactor.async do |task|
						raise SignalException.new(:TERM)
					end
				end
			end.to raise_exception(SignalException, message: be =~ /TERM/)
		end
	end
	
	with '#yield' do
		it "can yield back to reactor" do
			state = nil
			
			reactor.async do |task|
				state = :started
				task.yield
				state = :finished
			end
			
			reactor.run
			
			expect(state).to be == :finished
		end
	end
	
	with '#stop' do
		it "can be stopped" do
			state = nil
			
			reactor.run do
				task = reactor.async do |task|
					state = :started
					task.sleep(10)
					state = :finished
				end
				
				task.stop
				
				expect(task).to be(:stopped?)
			end
			
			expect(state).to be == :started
		end
		
		it "can stop nested tasks with exception handling" do
			reactor.run do
				task = reactor.async do |task|
					child = task.async do |subtask|
						subtask.sleep(1)
					end
					
					begin
						child.wait
					ensure
						child.stop
					end
				end
				
				subtask = task.children.first
				task.stop
				
				expect(task.status).to be == :stopped
				expect(subtask.status).to be == :stopped
			end
		end
		
		it "can stop current task" do
			state = nil
			
			reactor.run do
				task = reactor.async do |task|
					state = :started
					task.stop
					state = :finished
				end
				
				expect(state).to be == :started
				expect(task).to be(:stopped?)
			end
		end
		
		it "can stop the parent task" do
			reactor.run do
				reactor.async do |task|
					parent_task = task
					
					reactor.async do |task|
						parent_task.stop
					end
					
					sleep(100)
				end
			end
		end
		
		it "can stop current task using exception" do
			state = nil
			
			reactor.run do
				task = reactor.async do |task|
					state = :started
					raise Async::Stop, "I'm finished."
					state = :finished
				end
				
				expect(task).to be(:stopped?)
			end
			
			expect(state).to be == :started
		end
		
		it "can stop the current task later" do
			state = nil
			task = nil
			
			reactor.run do
				task = reactor.async do |task|
					task.stop(true)
					state = :sleeping
					sleep(1)
				end
			end
			
			expect(state).to be == :sleeping
			expect(task).to be(:stopped?)
		end
		
		it "should stop direct child" do
			parent_task = child_task = nil
			
			reactor.run do
				reactor.async do |task|
					parent_task = task
					
					task.async do |task|
						child_task = task
						
						task.sleep(10)
					end
					
					task.sleep(10)
				end
				
				expect(parent_task).not.to be_nil
				expect(child_task).not.to be_nil
				
				expect(parent_task.fiber).to be(:alive?)
				expect(child_task.fiber).to be(:alive?)
				
				parent_task.stop
				
				# We need to yield here to allow the tasks to be terminated. The parent task raises an exception in the child task and adds itself to the selector ready queue. It takes at least one iteration for the parent task to exit as well:
				reactor.yield
				
				expect(parent_task).not.to be(:alive?)
				expect(child_task).not.to be(:alive?)
			end
		end
			
		it "can stop a currently resumed task" do
			parent_task = nil
			
			reactor.run do
				reactor.async do |task|
					parent_task = task
					
					Fiber.new do
						task.async do
							parent_task.stop
						end
					end.resume
					
					task.sleep(1)
				end
			end
			
			expect(parent_task).to be(:stopped?)
		end
		
		it "can stop nested parent" do
			parent_task = nil
			children_tasks = []
			
			reactor.run do
				reactor.async do |task|
					parent_task = task
					
					task.async do |task|
						children_tasks << task
						task.sleep(0.02)
					end
					
					task.async do |task|
						children_tasks << task
						task.sleep(0.01)
						parent_task.stop
					end
					
					task.async do |task|
						children_tasks << task
						task.sleep(0.02)
					end
					
					task.sleep(0.02)
				end
			end
			
			expect(parent_task).not.to be(:alive?)
			
			children_tasks.each do |child|
				expect(child).not.to be(:alive?)
			end
		end
		
		it "should not remove running task" do
			top_task = middle_task = bottom_task = nil
			
			reactor.run do
				ready = Async::Queue.new
				
				reactor.async do |task|
					top_task = task
					
					top_task.async do |task|
						middle_task = task
						
						middle_task.async do |task|
							bottom_task = task
							
							ready.enqueue(true)
							
							task.sleep(10)
						end
						task.sleep(10)
					end
					task.sleep(10)
				end
				
				ready.dequeue
				
				bottom_task.stop
				expect(top_task.children).to be(:include?, middle_task)
				
				top_task.stop
			end
		end
		
		it "can stop resumed task" do
			items = [1, 2, 3]
			
			reactor.run do
				condition = Async::Condition.new
				
				producer = reactor.async do |subtask|
					while item = items.pop
						subtask.yield # (1) Fiber.yield, (3) Reactor -> producer.resume
						condition.signal(item) # (4) consumer.resume(value)
					end
				end
				
				value = condition.wait # (2) value = Fiber.yield
				expect(value).to be == 3
				producer.stop # (5) [producer is resumed already] producer.stop
			end
			
			expect(items).to be == [1, 2]
		end
	end
	
	with '#sleep' do
		let(:duration) {0.01}
		
		it "can sleep for the requested duration" do
			state = nil
			
			reactor.async do |task|
				task.sleep(duration)
				state = :finished
			end
			
			time = Async::Clock.measure do
				reactor.run
			end
			
			# This is too unstable on travis.
			# expect(time).to be_within(50).percent_of(duration)
			expect(time).to be >= duration
			expect(state).to be == :finished
		end
	end
	
	with '#with_timeout' do
		it "can extend timeout" do
			reactor.async do |task|
				task.with_timeout(0.2) do |timer|
					task.sleep(0.1)
					
					expect(timer.fires_in).to be_within(Q).of(0.1)
					
					timer.reset
					
					expect(timer.fires_in).to be_within(Q).of(0.2)
				end
			end
			
			reactor.run
		end
		
		it "will timeout if execution takes too long" do
			state = nil
			
			reactor.async do |task|
				begin
					task.with_timeout(0.01) do
						state = :started
						task.sleep(10)
						state = :finished
					end
				rescue Async::TimeoutError
					state = :timeout
				end
			end
			
			reactor.run
			
			expect(state).to be == :timeout
		end
		
		it "won't timeout if execution completes in time" do
			state = nil
			
			reactor.async do |task|
				state = :started
				task.with_timeout(0.01) do
					task.sleep(0.001)
					state = :finished
				end
			end
			
			reactor.run
			
			expect(state).to be == :finished
		end
		
		def sleep_forever
			while true
				Async::Task.current.sleep(1)
			end
		end
		
		it "contains useful backtrace" do
			task = Async do |task|
				task.with_timeout(0.001) do
					sleep_forever
				end
			end
			
			expect{task.wait}.to raise_exception(Async::TimeoutError)
			
			error = task.result
			expect(error.backtrace).to have_value(be =~ /sleep_forever/)
		end
	end
	
	with '#backtrace' do
		it "has a backtrace" do
			Async do
				task = Async do |task|
					task.sleep(1)
				end
				
				expect(task.backtrace).to have_value(be =~ /sleep/)
				
				task.stop
			end
		end
		
		with "finished task" do
			it "has no backtrace" do
				task = Async{}
				
				expect(task.backtrace).to be_nil
			end
		end
	end
	
	with '#wait' do
		it "will wait on another task to complete" do
			apples_task = reactor.async do |task|
				task.sleep(0.1)
				
				:apples
			end
			
			oranges_task = reactor.async do |task|
				task.sleep(0.01)
				
				:oranges
			end
			
			fruit_salad = reactor.async do |task|
				[apples_task.wait, oranges_task.wait]
			end
			
			reactor.run
			
			expect(fruit_salad.wait).to be == [:apples, :oranges]
		end
		
		it "will raise exceptions when checking result" do
			error_task = nil
			
			reactor.run do
				error_task = reactor.async do |task|
					raise RuntimeError, "brain not provided"
				end
				
				expect do
					error_task.wait
				end.to raise_exception(RuntimeError, message: be =~ /brain/)
			end
		end
		
		it "will propagate exceptions after async operation" do
			error_task = innocent_task = nil
			
			error_task = reactor.async do |task|
				task.sleep(0.1)
				
				raise "boom"
			end
			
			innocent_task = reactor.async do |task|
				expect{error_task.wait}.to raise_exception(RuntimeError, message: be =~ /boom/)
			end
			
			expect do
				reactor.run
			end.not.to raise_exception
			
			expect(error_task).to be(:finished?)
			expect(innocent_task).to be(:finished?)
		end
	end
	
	with '#result' do
		it 'does not raise exception' do
			reactor.async do
				task = reactor.async do
					raise "The space time converter has failed."
				end
				
				expect(task.result).to be_a(RuntimeError)
			end
		end
		
		it 'does not wait for task completion' do
			reactor.async do
				task = reactor.async do |task|
					task.sleep(1)
				end
				
				expect(task.result).to be_nil
				
				task.stop
			end
		end
	end
	
	with '#complete?' do
		with 'running task' do
			it 'is not complete?' do
				reactor.async do |task|
					expect(task).not.to be(:complete?)
				end
			end
		end
		
		with 'completed task' do
			it 'is complete?' do
				task = reactor.async{}
				expect(task).to be(:complete?)
			end
		end
	end
	
	with '#stopped?' do
		with 'running task' do
			it 'is not stopped?' do
				reactor.async do |task|
					expect(task).not.to be(:stopped?)
				end
			end
		end
		
		with 'stopped task' do
			it 'is stopped?' do
				reactor.async do |task|
					child = task.async do |task|
						sleep(1)
					end
					
					child.stop
					expect(child).to be(:stopped?)
				end
			end
		end
	end
	
	with '#children' do
		it "enumerates children in same order they are created" do
			tasks = 10.times.map do |i|
				reactor.async(annotation: "Task #{i}") {|task| task.sleep(1)}
			end
			
			expect(reactor.children.each.to_a).to be == tasks
		end
	end
	
	with '#to_s' do
		it "should show running" do
			apples_task = reactor.async do |task|
				task.sleep(0.1)
			end
			
			expect(apples_task.to_s).to be =~ /running/
		end
		
		it "should show complete" do
			reactor.run do
				apples_task = reactor.async do |task|
				end
				
				expect(apples_task.to_s).to be =~ /complete/
			end
		end
	end
end
