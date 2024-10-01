# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2020, by Brian Morearty.

require 'kernel/async'
require 'kernel/sync'

describe Kernel do
	with '#Sync' do
		let(:value) {10}
		
		it "can run a synchronous task" do
			result = Sync do |task|
				expect(Async::Task.current).not.to be == nil
				expect(Async::Task.current).to be == task
				
				next value
			end
			
			expect(result).to be == value
		end

		it "passes options through to initial task" do
			Sync(annotation: 'foobar') do |task|
				expect(task.annotation).to be == 'foobar'
			end
		end
		
		it "can run inside reactor" do
			Async do |task|
				result = Sync do |sync_task|
					expect(Async::Task.current).to be == task
					expect(sync_task).to be == task
					
					next value
				end
				
				expect(result).to be == value
			end
		end
		
		it "can propagate error without logging them" do
			expect(Console).not.to receive(:error)
			
			expect do
				Sync do
					raise StandardError, "brain not provided"
				end
			end.to raise_exception(StandardError, message: be =~ /brain/)
		end
	end
end
