# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

require 'kernel/async'

describe Kernel do
	describe '.Async' do
		it "can run an asynchronous task" do
			Async do |task|
				expect(task).to be_a Async::Task
			end
		end
		
		it "passes options through to initial task" do
			Async(transient: true) do |task|
				expect(task).to be(:transient?)
			end
		end
	end
end
