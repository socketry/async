# frozen_string_literal: true

require_relative "lib/async/version"

Gem::Specification.new do |spec|
	spec.name = "async"
	spec.version = Async::VERSION
	
	spec.summary = "A concurrency framework for Ruby."
	spec.authors = ["Samuel Williams", "Bruno Sutic", "Jeremy Jung", "Devin Christensen", "Kent Gruber", "Brian Morearty", "Colin Kelley", "Jiang Jinyang", "Julien Portalier", "Jun Jiang", "Ken Muryoi", "Leon Löchner", "Masafumi Okura", "Masayuki Yamamoto", "Olle Jonsson", "Patrik Wenger", "Ryan Musgrave", "Salim Semaoune", "Shannon Skipper", "Sokolov Yura", "Stefan Wrobel", "Trevor Turk"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/async"
	
	spec.metadata["documentation_uri"] = "https://socketry.github.io/async/"
	
	spec.files = Dir.glob(['{lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.1.1"
	
	spec.add_dependency "console", "~> 1.10"
	spec.add_dependency "fiber-annotation"
	spec.add_dependency "io-event", "~> 1.1"
	spec.add_dependency "timers", "~> 4.1"
	
	spec.add_development_dependency "bake-test"
	spec.add_development_dependency "bake-test-external"
	spec.add_development_dependency "benchmark-ips"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered", "~> 0.18.3"
	spec.add_development_dependency "sus", "~> 0.15"
	spec.add_development_dependency "sus-fixtures-async"
end
