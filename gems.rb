# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2024, by Patrik Wenger.

source 'https://rubygems.org'

gemspec

# gem "io-event", git: "https://github.com/socketry/io-event.git"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	
	gem "utopia-project"
	gem "bake-releases"
end

group :test do
	gem "sus", "~> 0.29", ">= 0.29.1"
	gem "covered"
	gem "decode"
	gem "rubocop"
	
	gem "sus-fixtures-async"
	gem "sus-fixtures-console", "~> 0.3"
	
	gem "bake-test"
	gem "bake-test-external"
	
	gem "benchmark-ips"
end
