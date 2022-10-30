# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'sus/fixtures/async'

describe Process do
	include Sus::Fixtures::Async::ReactorContext

	describe '.wait2' do
		it "can wait on child process" do
			expect(reactor).to receive(:process_wait)
			
			pid = ::Process.spawn("true")
			_, status = Process.wait2(pid)
			expect(status).to be(:success?)
		end
	end
end
