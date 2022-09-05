# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/rspec'
require 'tempfile'

RSpec.describe Tempfile do
	include_context Async::RSpec::Reactor
	
	it "should be able to read and write" do
		1_000.times{subject.write("Hello World!")}
		subject.flush

		subject.seek(0)
		
		expect(subject.read(12)).to be == "Hello World!"
	ensure
		subject.close
	end
end
