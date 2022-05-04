#!/usr/bin/env ruby

# abort "Need IO::Buffer" unless IO.const_defined?(:Buffer)

require_relative '../../lib/async'

file = File.open("/dev/zero")

Async do
	binding.irb
end
