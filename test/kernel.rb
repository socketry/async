# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "sus/fixtures/async"

describe Kernel do
	include Sus::Fixtures::Async::ReactorContext
	
	with "#sleep" do
		it "can intercept sleep" do
			sleeps = []
			
			mock(reactor) do |mock|
				mock.before(:kernel_sleep) do |duration|
					sleeps << duration
				end
			end
			
			sleep(0.001)
			
			expect(sleeps).to be(:include?, 0.001)
		end
	end
	
	with "#system" do
		it "can execute child process" do
			expect(reactor).to receive(:process_wait)
			
			result = ::Kernel.system("true")
			
			expect(result).to be == true
			expect($?).to be(:success?)
		end
		
		it "can fail to execute child process" do
			expect(reactor).to receive(:process_wait)
			
			result = ::Kernel.system("does-not-exist")
			
			expect(result).to be == nil
			expect($?).not.to be(:success?)
		end
	end
	
	with "#`" do
		it "can execute child process and capture output" do
			expect(`echo OK`).to be == "OK\n"
			expect($?).to be(:success?)
		end
		
		it "can execute child process with delay and capture output" do
			expect(`sleep 0.01; echo OK`).to be == "OK\n"
			expect($?).to be(:success?)
		end
		
		it "can echo several times" do
			10.times do
				expect(`echo test`).to be == "test\n"
				expect($?).to be(:success?)
				expect($?.inspect).to be =~ /exit 0/
			end
		end
	end
end
