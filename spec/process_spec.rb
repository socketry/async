# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/rspec'

RSpec.describe Process do
	include_context Async::RSpec::Reactor

	describe '.wait2' do
		it "can wait on child process" do
			expect(reactor).to receive(:process_wait).and_call_original
			
			pid = ::Process.spawn("true")
			_, status = Process.wait2(pid)
			expect(status).to be_success
		end
	end
end
