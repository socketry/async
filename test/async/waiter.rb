
require 'async/waiter'
require 'sus/fixtures/async'

describe Async::Waiter do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:waiter) {subject.new}
	
	it "can wait for a subset of tasks" do
		3.times do
			waiter.async do
				sleep(rand * 0.01)
			end
		end
		
		done = waiter.wait(2)
		expect(done.size).to be == 2
		
		done = waiter.wait(1)
		expect(done.size).to be == 1
	end
	
	it "can wait for tasks even when exceptions occur" do
		waiter.async do
			raise "Something went wrong"
		end
		
		expect do
			waiter.wait
		end.to raise_exception(RuntimeError)
	end
end
