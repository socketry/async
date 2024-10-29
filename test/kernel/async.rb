# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2024, by Patrik Wenger.

require "kernel/async"

describe Kernel do
	describe ".Async" do
		it "can run an asynchronous task" do
			Async do |task|
				expect(task).to be_a Async::Task
			end
		end
		
		it "passes transient: options through to initial task" do
			Async(transient: true) do |task|
				expect(task).to be(:transient?)
			end
		end
		
		it "passes annotation: option through to initial task" do
			Async(annotation: "foobar") do |task|
				expect(task.annotation).to be == "foobar"
			end
		end
	end
end
