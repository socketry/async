# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

module ChildProcess
	def self.spawn(code)
		lib_path = File.expand_path("../lib", __dir__)
		
		IO.popen(["ruby", "-I#{lib_path}"], "r+", err: [:child, :out]) do |process|
			process.write(code)
			process.close_write
			
			return process.read
		end
	end
end
