# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require "async"

Async do |t|
	t.async do
		puts "1\n"
	end
	
	t.async do
		puts "2\n"
	end
end
