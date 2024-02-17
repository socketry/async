# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.
# Copyright, 2017, by Devin Christensen.

require 'async'
require 'sus/fixtures/async'
require 'benchmark/ips'

describe Async::Reactor do
	let(:reactor) {subject.new}
	
	with '#run' do
		it "can run tasks on different fibers" do
			outer_fiber = Fiber.current
			inner_fiber = nil
			
			subject.run do |task|
				task.sleep(0)
				inner_fiber = Fiber.current
			end
			
			expect(inner_fiber).not.to be_nil
			expect(outer_fiber).not.to be == inner_fiber
		end
	end
	
	with '#close' do
		it "can close empty reactor" do
			reactor.close
			
			expect(reactor).to be(:closed?)
		end
		
		it "terminates transient tasks" do
			task = reactor.async(transient: true) do
				sleep
			ensure
				sleep
			end
			
			expect(reactor.run_once).to be == false
			expect(reactor).to be(:finished?)
			reactor.close
		end
		
		it "terminates transient tasks with nested tasks" do
			task = reactor.async(transient: true) do |parent|
				parent.async do |child|
					sleep(1)
				end
			end
			
			reactor.run_once
			expect(reactor).to be(:finished?)
			reactor.close
		end
		
		it "terminates nested tasks" do
			top = reactor.async do |parent|
				parent.async do |child|
					child.sleep(1)
				end
			end
			
			reactor.run_once
			reactor.close
		end
	end
	
	with '#run' do
		it "can run the reactor" do
			# Run the reactor for 1 second:
			task = reactor.async do |task|
				task.yield
			end
			
			expect(task).to be(:running?)
			
			# This will resume the task, and then the reactor will be finished.
			reactor.run
			
			expect(task).to be(:finished?)
		end
		
		it "can run one iteration" do
			state = :started
			
			reactor.async do |task|
				task.yield
				state = :finished
			end
			
			expect(state).to be == :started
			
			reactor.run
			
			expect(state).to be == :finished
		end
	end
	
	with '#print_hierarchy' do
		it "can print hierarchy" do
			reactor.async do |parent|
				parent.async do |child|
					child.yield
				end
				
				output = StringIO.new
				reactor.print_hierarchy(output, backtrace: false)
				lines = output.string.lines
				
				expect(lines[0]).to be =~ /#<Async::Reactor/
				expect(lines[1]).to be =~ /\t#<Async::Task.*(running)/
				expect(lines[2]).to be =~ /\t\t#<Async::Task.*(running)/
			end
			
			reactor.run
		end
		
		it "can include backtrace" do
			reactor.async do |parent|
				child = parent.async do |child|
					child.sleep 1
				end
				
				output = StringIO.new
				reactor.print_hierarchy(output, backtrace: true)
				lines = output.string.lines
				
				expect(lines).to have_value(be =~ /in .*sleep'/)
				
				child.stop
			end
			
			reactor.run
		end
	end
	
	with '#stop' do
		it "can stop the reactor" do
			state = nil
			
			reactor.async(annotation: "sleep(10)") do |task|
				state = :started
				task.sleep(10)
				state = :stopped
			end
			
			reactor.async(annotation: "reactor.stop") do |task|
				task.sleep(0.01)
				task.reactor.stop
			end
			
			reactor.run
			
			expect(state).to be == :started
			
			reactor.close
		end
		
		it "can stop reactor from different thread" do
			events = Thread::Queue.new
			
			reactor = self.reactor
			
			thread = Thread.new do
				if events.pop
					# The reactor interrupt mechanism is not a guaranteed robust mechanism. Interrupts can be missed if the interrupt is received before entering sleep. Making this more reliable in the future might be useful.
					2.times do
						reactor.interrupt
						sleep(0.01)
					end
				end
			end
			
			reactor.async do
				events << true
				# Wait to be interrupted:
				sleep
			end
			
			reactor.run
			
			thread.join
			expect(thread).not.to be(:alive?)
			
			expect(reactor).not.to be(:stopped?)
		end
	end
	
	it "can't return" do
		expect do
			Async do |task|
				return
			end.wait
		end.to raise_exception(LocalJumpError)
	end
	
	it "is closed after running" do
		reactor = nil
		
		Async do |task|
			reactor = task.reactor
		end
		
		expect(reactor).to be(:closed?)
		
		expect{reactor.run}.to raise_exception(RuntimeError, message: be =~ /closed/)
	end
	
	it "should return a task" do
		result = Async do |task|
		end
		
		expect(result).to be_a(Async::Task)
	end
	
	with '#async' do
		include Sus::Fixtures::Async::ReactorContext
		
		it "can pass in arguments" do
			reactor.async(:arg) do |task, arg|
				expect(arg).to be == :arg
			end.wait
		end
		
		it "passes in the correct number of arguments" do
			reactor.async(:arg1, :arg2, :arg3) do |task, arg1, arg2, arg3|
				expect(arg1).to be == :arg1
				expect(arg2).to be == :arg2
				expect(arg3).to be == :arg3
			end.wait
		end
	end
	
	with '#with_timeout' do
		let(:duration) {1}
		
		it "stops immediately" do
			start_time = Time.now
			
			subject.run do |task|
				condition = Async::Condition.new
				
				task.with_timeout(duration) do
					task.async do
						condition.wait
					end
					
					condition.signal
					
					task.yield
					
					task.children.each(&:wait)
				end
			end
			
			duration = Time.now - start_time
			
			expect(duration).to be < 0.1
		end
		
		let(:timeout_class) {Class.new(RuntimeError)}
		
		it "raises specified exception" do
			expect do
				subject.run do |task|
					task.with_timeout(0.0, timeout_class) do
						task.sleep(1.0)
					end
				end.wait
			end.to raise_exception(timeout_class)
		end
	end
	
	with '#to_s' do
		it "shows stopped" do
			expect(reactor.to_s).to be =~ /stopped/
		end
	end
	
	it "validates scheduler assignment" do
		# Assign the scheduler:
		reactor = self.reactor
		
		# Close the previous scheduler:
		Async {}
		
		expect do
			# The reactor is closed:
			reactor.async {}
		end.to raise_exception(Async::Scheduler::ClosedError)
	end
end
