
require 'async/io'

RSpec.describe Async::IO do
	include_context Async::RSpec::Reactor
	
	let(:pipe) {IO.pipe}
	let(:input) {pipe.last}
	let(:output) {pipe.first}
	
	it "should send and receive data within the same reactor" do
		message = nil
		
		output_task = reactor.with(output) do |wrapper|
			message = wrapper.read(1024)
		end
		
		reactor.with(input) do |wrapper|
			wrapper.write("Hello World")
		end
		
		output_task.wait
		expect(message).to be == "Hello World"
	end
end
