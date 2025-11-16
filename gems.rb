# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2025, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2024, by Patrik Wenger.

source "https://rubygems.org"

gemspec

# gem "io-event", git: "https://github.com/socketry/io-event.git"

# In order to capture both code paths in coverage, we need to optionally load this gem:
if ENV["FIBER_PROFILER_CAPTURE"] == "true"
	gem "fiber-profiler"
end

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	gem "bake-releases"
	
	gem "agent-context"
	
	gem "utopia-project"
end

group :test do
	gem "sus", "~> 0.31"
	gem "covered"
	gem "decode"
	
	gem "rubocop"
	gem "rubocop-socketry"
	
	gem "sus-fixtures-async"
	gem "sus-fixtures-console"
	gem "sus-fixtures-time"
	gem "sus-fixtures-benchmark"
	gem "sus-fixtures-agent-context"
	
	gem "bake-test"
	gem "bake-test-external"
	
	gem "benchmark-ips"
	gem "openssl", "~> 3.3.2"
end
