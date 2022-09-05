# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.
# Copyright, 2020, by Brian Morearty.

require 'kernel/async'
require 'kernel/sync'

RSpec.describe Kernel do
	describe '#Sync' do
		let(:value) {10}
		
		it "can run a synchronous task" do
			result = Sync do |task|
				expect(Async::Task.current).to_not be nil
				expect(Async::Task.current).to be task
				
				next value
			end
			
			expect(result).to be == value
		end
		
		it "can run inside reactor" do
			Async do |task|
				result = Sync do |sync_task|
					expect(Async::Task.current).to be task
					expect(sync_task).to be task
					
					next value
				end
				
				expect(result).to be == value
			end
		end
		
		it "can propagate error without logging them" do
			expect(Console.logger).to_not receive(:error)
			
			expect do
				Sync do
					raise StandardError, "brain not provided"
				end
			end.to raise_exception(StandardError, /brain/)
		end
	end
end
