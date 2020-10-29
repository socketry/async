
require_relative "lib/async/version"

Gem::Specification.new do |spec|
	spec.name = "async"
	spec.version = Async::VERSION
	
	spec.summary = "A concurrency framework for Ruby."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.homepage = "https://github.com/socketry/async"
	
	spec.files = Dir.glob('{lib}/**/*', File::FNM_DOTMATCH, base: __dir__)
	
	spec.required_ruby_version = ">= 2.5.0"
	
	spec.add_dependency "console", "~> 1.10"
	spec.add_dependency "nio4r", "~> 2.3"
	spec.add_dependency "timers", "~> 4.1"
	
	spec.add_development_dependency "async-rspec", "~> 1.1"
	spec.add_development_dependency "bake"
	spec.add_development_dependency "benchmark-ips"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "covered", "~> 0.10"
	spec.add_development_dependency "rspec", "~> 3.6"
end
