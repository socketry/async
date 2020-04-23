
require_relative 'lib/async/version'

Gem::Specification.new do |spec|
	spec.name = "async"
	spec.version = Async::VERSION
	spec.authors = ["Samuel Williams"]
	spec.email = ["samuel.williams@oriontransfer.co.nz"]
	spec.description = <<-EOF
		Async is a modern concurrency framework for Ruby. It implements the
		reactor pattern, providing both non-blocking I/O and timer events.
	EOF
	spec.summary = "Async is a concurrency framework for Ruby."
	spec.homepage = "https://github.com/socketry/async"
	spec.license = "MIT"
	
	spec.files = `git ls-files`.split($/)
	spec.executables = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
	spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]
	
	spec.required_ruby_version = ">= 2.5.0"
	
	spec.add_runtime_dependency "nio4r", "~> 2.3"
	spec.add_runtime_dependency "timers", "~> 4.1"
	spec.add_runtime_dependency "console", "~> 1.0"
	
	spec.add_development_dependency "async-rspec", "~> 1.1"
	
	spec.add_development_dependency "covered", "~> 0.10"
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "rspec", "~> 3.6"
	spec.add_development_dependency "bake-bundler"
end
