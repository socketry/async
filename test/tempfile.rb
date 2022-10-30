# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'tempfile'
require 'sus/fixtures/async'

describe Tempfile do
	include Sus::Fixtures::Async::ReactorContext
	
	it "should be able to read and write" do
		tempfile = Tempfile.new
		
		1_000.times{tempfile.write("Hello World!")}
		tempfile.flush

		tempfile.seek(0)
		
		expect(tempfile.read(12)).to be == "Hello World!"
	ensure
		tempfile.close
	end
end
