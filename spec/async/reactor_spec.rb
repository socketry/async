# frozen_string_literal: true

# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'async'
require 'async/rspec/reactor'

require 'benchmark/ips'

RSpec.describe Async::Reactor do
	describe '#run' do
		it "can run tasks on different fibers" do
			outer_fiber = Fiber.current
			inner_fiber = nil
			
			described_class.run do |task|
				task.sleep(0)
				inner_fiber = Fiber.current
			end
			
			expect(inner_fiber).to_not be nil
			expect(outer_fiber).to_not be == inner_fiber
		end
	end
	
	describe '#close' do
		it "can close empty reactor" do
			subject.close
			
			expect(subject).to be_closed
		end
	end
	
	describe '#run' do
		it "can run the reactor" do
			# Run the reactor for 1 second:
			task = subject.async do |task|
				task.yield
			end
			
			expect(task).to be_running
			
			# This will resume the task, and then the reactor will be finished.
			subject.run
			
			expect(task).to be_finished
		end
		
		it "can run one iteration" do
			state = :started
			
			subject.async do |task|
				task.yield
				state = :finished
			end
			
			expect(state).to be :started
			
			subject.run
			
			expect(state).to be :finished
		end
	end
	
	describe '#print_hierarchy' do
		it "can print hierarchy" do
			subject.async do |parent|
				parent.async do |child|
					child.yield
				end
				
				output = StringIO.new
				subject.print_hierarchy(output, backtrace: false)
				lines = output.string.lines
				
				expect(lines[0]).to be =~ /#<Async::Reactor/
				expect(lines[1]).to be =~ /\t#<Async::Task.*(running)/
				expect(lines[2]).to be =~ /\t\t#<Async::Task.*(running)/
			end
			
			subject.run
		end
		
		it "can include backtrace", if: Fiber.current.respond_to?(:backtrace) do
			subject.async do |parent|
				child = parent.async do |child|
					child.sleep 1
				end
				
				output = StringIO.new
				subject.print_hierarchy(output, backtrace: true)
				lines = output.string.lines
				
				expect(lines).to include(/in `sleep'/)
				
				child.stop
			end
		end
	end
	
	describe '#stop' do
		it "can stop the reactor" do
			state = nil
			
			subject.async(annotation: "sleep(10)") do |task|
				state = :started
				task.sleep(10)
				state = :stopped
			end
			
			subject.async(annotation: "reactor.stop") do |task|
				task.sleep(0.1)
				task.reactor.stop
			end
			
			subject.run
			
			expect(state).to be == :started
			
			subject.close
		end
		
		it "can stop reactor from different thread" do
			events = Thread::Queue.new
			
			thread = Thread.new do
				if events.pop
					sleep 0.2
					subject.interrupt
				end
			end
			
			subject.async do
				events << true
				
				# Wait to be interrupted:
				sleep
			end
			
			expect do
				subject.run
			end.to raise_error(Interrupt)
			
			thread.join
			expect(thread).to_not be_alive
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
		
		expect(reactor).to be_closed
		
		expect{reactor.run}.to raise_exception(RuntimeError, /closed/)
	end
	
	it "should return a task" do
		result = Async do |task|
		end
		
		expect(result).to be_kind_of(Async::Task)
	end
	
	describe '#async' do
		include_context Async::RSpec::Reactor
		
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
	
	describe '#with_timeout' do
		let(:duration) {1}
		
		it "stops immediately" do
			start_time = Time.now
			
			described_class.run do |task|
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
				described_class.run do |task|
					task.with_timeout(0.0, timeout_class) do
						task.sleep(1.0)
					end
				end.wait
			end.to raise_exception(timeout_class)
		end
		
		it "should be fast to use timeouts" do
			Benchmark.ips do |x|
				x.report('Reactor#with_timeout') do |repeats|
					Async do |task|
						reactor = task.reactor
						
						repeats.times do
							reactor.with_timeout(1) do
							end
						end
					end
				end
				
				x.compare!
			end
		end
	end
	
	describe '#to_s' do
		it "shows stopped=" do
			expect(subject.to_s).to include "stopped"
		end
	end
end
