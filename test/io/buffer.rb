# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

describe IO::Buffer do
	it "can copy a large buffer (releasing the GVL)" do
		source = IO::Buffer.new(1024 * 1024 * 10)
		destination = IO::Buffer.new(source.size)
		
		source.copy(destination)
	end
end
