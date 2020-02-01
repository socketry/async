# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do
	gem 'pry'
	gem 'guard-rspec'
	gem 'guard-yard'
	
	gem 'yard'
end

group :test do
	gem 'benchmark-ips'
	gem 'ruby-prof', platforms: :mri
	
	gem 'covered', require: 'covered/rspec'
end
