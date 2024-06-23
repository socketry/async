# frozen_string_literal: true

require_relative "lib/async/version"

Gem::Specification.new do |spec|
	spec.name = "async"
	spec.version = Async::VERSION
	
	spec.summary = "A concurrency framework for Ruby."
	spec.authors = ["Samuel Williams", "Bruno Sutic", "Jeremy Jung", "Olle Jonsson", "Devin Christensen", "Emil Tin", "Kent Gruber", "Brian Morearty", "Colin Kelley", "Dimitar Peychinov", "Gert Goet", "Jiang Jinyang", "Julien Portalier", "Jun Jiang", "Ken Muryoi", "Leon Löchner", "Masafumi Okura", "Masayuki Yamamoto", "Math Ieu", "Patrik Wenger", "Ryan Musgrave", "Salim Semaoune", "Shannon Skipper", "Sokolov Yura", "Stefan Wrobel", "Trevor Turk"]
	spec.license = "MIT"
	
	spec.cert_chain  = ['release.cert']
	spec.signing_key = File.expand_path('~/.gem/release.pem')
	
	spec.homepage = "https://github.com/socketry/async"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async/",
		"funding_uri" => "https://github.com/sponsors/ioquatix/",
		"source_code_uri" => "https://github.com/socketry/async.git",
	}
	
	spec.files = Dir.glob(['{lib}/**/*', '*.md'], File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 3.1.1"
	
	spec.add_dependency "console", ["~> 1.25", ">= 1.25.2"]
	spec.add_dependency "fiber-annotation"
	spec.add_dependency "io-event", ["~> 1.6", ">= 1.6.5"]
end
