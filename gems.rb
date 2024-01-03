# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.

source 'https://rubygems.org'

gemspec

# gem "io-event", git: "https://github.com/socketry/io-event.git"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	
	gem "bake-github-pages"
	gem "utopia-project"
end

group :test do
	gem "bake-test"
	gem "bake-test-external"
	gem "benchmark-ips"
	gem "covered", "~> 0.18.3"
	gem "sus", "~> 0.15"
	gem "sus-fixtures-async"
end
