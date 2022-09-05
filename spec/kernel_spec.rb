# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/rspec'

RSpec.describe Kernel do
	include_context Async::RSpec::Reactor

	describe '#sleep' do
		it "can intercept sleep" do
			expect(reactor).to receive(:kernel_sleep).with(0.001)
			
			sleep(0.001)
		end
	end
	
	describe '#system' do
		it "can execute child process" do
			# expect(reactor).to receive(:process_wait).and_call_original
			
			::Kernel.system("true")
			expect($?).to be_success
		end
	end
	
	describe '#`' do
		it "can execute child process and capture output" do
			expect(`echo OK`).to be == "OK\n"
			expect($?).to be_success
		end
		
		it "can execute child process with delay and capture output" do
			expect(`sleep 1; echo OK`).to be == "OK\n"
			expect($?).to be_success
		end
	end
end
