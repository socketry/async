#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

# abort "Need IO::Buffer" unless IO.const_defined?(:Buffer)

require_relative '../../lib/async'

file = File.open("/dev/zero")

Async do
	binding.irb
end
