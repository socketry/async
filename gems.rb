# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2020-2022, by Samuel Williams.

source 'https://rubygems.org'

gemspec

# gem "io-event", git: "https://github.com/socketry/io-event.git"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	
	gem "bake-github-pages"
	gem "utopia-project"
end

# gem "async-rspec", path: "../async-rspec"
# gem "rspec-files", path: "../rspec-files"
