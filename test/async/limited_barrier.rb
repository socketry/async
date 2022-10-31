
require 'async/limited_barrier'
require 'sus/fixtures/async'

describe Async::LimitedBarrier do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:limited_barrier) {subject.new}
	
	it "can wait for a subset of tasks" do
		3.times do
			limited_barrier.async do
				sleep(rand * 0.01)
			end
		end
		
		done = limited_barrier.wait(2)
		expect(done.size).to be == 2

		done = limited_barrier.wait(1)
		expect(done.size).to be == 1
	end
end
