# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.
# Copyright, 2022, by Shannon Skipper.

require 'async/node'

describe Async::Children do
	let(:children) {subject.new}
	
	with "no children" do
		it "should be empty" do
			expect(children).to be(:empty?)
			expect(children).to be(:nil?)
			expect(children).not.to be(:transients)
		end
	end
end
