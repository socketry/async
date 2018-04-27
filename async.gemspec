
require_relative 'lib/async/version'

Gem::Specification.new do |spec|
	spec.name          = "async"
	spec.version       = Async::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	spec.description   = <<-EOF
		Async provides a modern asynchronous I/O framework for Ruby, based
		on nio4r. It implements the reactor pattern, providing both IO and timer
		based events.
	EOF
	spec.summary       = "Async is an asynchronous I/O framework based on nio4r."
	spec.homepage      = "https://github.com/socketry/async"
	spec.license       = "MIT"

	spec.files         = `git ls-files`.split($/)
	spec.executables   = spec.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
	spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
	spec.require_paths = ["lib"]
	spec.has_rdoc      = "yard"
	
	spec.required_ruby_version = ">= 2.2.7"

	spec.add_runtime_dependency "nio4r", "~> 2.3"
	spec.add_runtime_dependency "timers", "~> 4.1"
	
	spec.add_development_dependency "async-rspec", "~> 1.1"
	
	spec.add_development_dependency "bundler", "~> 1.3"
	spec.add_development_dependency "rspec", "~> 3.6"
	spec.add_development_dependency "rake"
end
