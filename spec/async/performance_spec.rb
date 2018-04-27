
require 'benchmark/ips'

RSpec.describe Async::Wrapper do
	let(:pipe) {IO.pipe}
	
	let(:input) {described_class.new(pipe.first)}
	let(:output) {described_class.new(pipe.last)}
		
	it "should be fast to wait until readable" do
		Benchmark.ips do |x|
			x.report('Wrapper#wait_readable') do |repeats|
				Async::Reactor.run do |task|
					input = Async::Wrapper.new(pipe.first, task.reactor)
					output = pipe.last
					
					repeats.times do
						output.write(".")
						input.wait_readable
						input.io.read(1)
					end
					
					input.reactor = nil
				end
			end
			
			x.report('Reactor#register') do |repeats|
				Async::Reactor.run do |task|
					input = pipe.first
					monitor = task.reactor.register(input, :r)
					output = pipe.last
					
					repeats.times do
						output.write(".")
						Async::Task.yield
						input.read(1)
					end
					
					monitor.close
				end
			end
			
			x.compare!
		end
	end
end
