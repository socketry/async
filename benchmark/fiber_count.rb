# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

fibers = []

(1..).each do |i|
	fibers << Fiber.new{}
	fibers.last.resume
	puts i
end

