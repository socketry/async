# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

# gem "event", path: "../event"
# gem "async-rspec", path: "../async-rspec"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	
	gem "utopia-project"
end

gem "io-event", git: "https://github.com/socketry/io-event", branch: "debug"

# gem "async-rspec", path: "../async-rspec"
# gem "rspec-files", path: "../rspec-files"
