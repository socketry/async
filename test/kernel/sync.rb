# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2024, by Samuel Williams.
# Copyright, 2020, by Brian Morearty.
# Copyright, 2024, by Patrik Wenger.

require "kernel/async"
require "kernel/sync"

describe Kernel do
	with "#Sync" do
		let(:value) {10}
		
		it "can run a synchronous task" do
			result = Sync do |task|
				expect(Async::Task.current).not.to be == nil
				expect(Async::Task.current).to be == task
				
				next value
			end
			
			expect(result).to be == value
		end
		
		it "passes annotation through to initial task" do
			Sync(annotation: "foobar") do |task|
				expect(task.annotation).to be == "foobar"
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
		
		with "parent task" do
			it "replaces and restores existing task's annotation" do
				annotations = []
				
				Async(annotation: "foo") do |t1|
					annotations << t1.annotation
					
					Sync(annotation: "bar") do |t2|
						expect(t2).to be_equal(t1)
						annotations << t1.annotation
					end
					
					annotations << t1.annotation
				end.wait
				
				expect(annotations).to be == %w[foo bar foo]
			end
		end
		
		it "can propagate error without logging them" do
			expect do
				Sync do |task|
					expect(task).not.to receive(:warn)
					
					raise StandardError, "brain not provided"
				end
			end.to raise_exception(StandardError, message: be =~ /brain/)
		end
	end
end
