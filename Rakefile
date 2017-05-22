require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:test)

task :default => :test

task :coverage do
	ENV['COVERAGE'] = 'y'
end