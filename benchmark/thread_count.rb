# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

threads = []

(1..).each do |i|
	threads << Thread.new{sleep}
	puts i
end

