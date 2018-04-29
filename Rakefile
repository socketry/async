require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:test)

task :default => :test

def clone_and_test(name)
	sh("git clone https://git@github.com/socketry/#{name}")
	
	# I tried using `bundle config --local local.async ../` but it simply doesn't work.
	File.open("#{name}/Gemfile", "a") do |file| 
		file.puts('gem "async", path: "../"')
	end
	
	sh("cd #{name} && bundle install && bundle exec rake test")
end

task :external do
	Bundler.with_clean_env do
		clone_and_test("async-io")
		clone_and_test("async-websocket")
		clone_and_test("async-dns")
		clone_and_test("async-http")
		clone_and_test("falcon")
	end
end

task :coverage do
	ENV['COVERAGE'] = 'y'
end