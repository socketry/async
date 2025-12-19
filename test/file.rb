# frozen_string_literal: true

require "async"
require "securerandom"
require "tmpdir"
require "sus/fixtures/temporary_directory_context"
require "sus/fixtures/async/scheduler_context"

describe File do
	include Sus::Fixtures::TemporaryDirectoryContext
	include Sus::Fixtures::Async::SchedulerContext
	
	let(:path) {File.join(root, "test.txt")}
	
	describe "#flush" do
		it "flushes the file's contents to disk" do
			File.open(path, "w+") do |file|
				file << "Hello World!"
			end
			
			expect(File.read(path)).to be == "Hello World!"
		end
	end
end
