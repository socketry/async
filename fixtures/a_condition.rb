# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2018-2022, by Samuel Williams.

require 'async/variable'

ACondition = Sus::Shared("a condition") do
	let(:condition) {subject.new}
	
	it 'can signal waiting task' do
		state = nil
		
		reactor.async do
			state = :waiting
			condition.wait
			state = :resumed
		end
		
		expect(state).to be == :waiting
		
		condition.signal
		
		reactor.yield
		
		expect(state).to be == :resumed
	end
	
	it 'should be able to signal stopped task' do
		expect(condition).to be(:empty?)
		
		task = reactor.async do
			condition.wait
		end
		
		expect(condition.empty?).not.to be(:empty?)
		
		task.stop
		
		condition.signal
	end
	
	it 'resumes tasks in order' do
		order = []
		
		5.times do |i|
			task = reactor.async do
				condition.wait
				order << i
			end
		end
		
		condition.signal
		
		reactor.yield
		
		expect(order).to be == [0, 1, 2, 3, 4]
	end
	
	with "timeout" do
		let(:ready) {Async::Variable.new(condition)}
		let(:waiting) {Async::Variable.new(subject.new)}
		
		def before
			@state = nil
			
			@task = reactor.async do |task|
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
			
			super
		end
		
		it 'can timeout while waiting' do
			@task.wait
			
			expect(@state).to be == :timeout
		end
		
		it 'can signal while waiting' do
			waiting.wait
			ready.resolve
			
			@task.wait
			
			expect(@state).to be == :signalled
		end
	end
end
