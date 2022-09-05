# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.

require 'async/variable'

RSpec.shared_examples Async::Condition do
	it 'can signal waiting task' do
		state = nil
		
		reactor.async do
			state = :waiting
			subject.wait
			state = :resumed
		end
		
		expect(state).to be == :waiting
		
		subject.signal
		
		reactor.yield
		
		expect(state).to be == :resumed
	end
	
	it 'should be able to signal stopped task' do
		expect(subject.empty?).to be_truthy
		
		task = reactor.async do
			subject.wait
		end
		
		expect(subject.empty?).to be_falsey
		
		task.stop
		
		subject.signal
	end
	
	it 'resumes tasks in order' do
		order = []
		
		5.times do |i|
			task = reactor.async do
				subject.wait
				order << i
			end
		end
		
		subject.signal
		
		reactor.yield
		
		expect(order).to be == [0, 1, 2, 3, 4]
	end
	
	context "with timeout" do
		let!(:ready) {Async::Variable.new(subject)}
		let!(:waiting) {Async::Variable.new(described_class.new)}
		
		before do
			@state = nil
		end
		
		let!(:task) do
			reactor.async do |task|
				task.with_timeout(0.1) do
					begin
						@state = :waiting
						waiting.resolve
						
						ready.wait
						@state = :signalled
					rescue Async::TimeoutError
						@state = :timeout
					end
				end
			end
		end
		
		it 'can timeout while waiting' do
			task.wait
			
			expect(@state).to be == :timeout
		end
		
		it 'can signal while waiting' do
			waiting.wait
			ready.resolve
			
			task.wait
			
			expect(@state).to be == :signalled
		end
	end
end
