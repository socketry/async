# frozen_string_literal: true

require 'async/rspec'
require 'covered/rspec'

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
