# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.

require 'covered/rspec'
require 'console'

if RUBY_PLATFORM =~ /darwin/
	Q = 20
else
	Q = 1
end

RSpec.configure do |config|
	# Enable flags like --only-failures and --next-failure
	config.example_status_persistence_file_path = ".rspec_status"

	config.expect_with :rspec do |c|
		c.syntax = :expect
	end
end
