# frozen_string_literal: true

def external
	require 'bundler'
	
	Bundler.with_clean_env do
		clone_and_test("async-io")
		clone_and_test("async-pool", "sus")
		clone_and_test("async-websocket", "sus")
		clone_and_test("async-dns")
		clone_and_test("async-http")
		clone_and_test("falcon")
		clone_and_test("async-rest")
	end
end

private

def clone_and_test(name, command = "rspec")
	require 'fileutils'
	
	path = "external/#{name}"
	FileUtils.rm_rf path
	FileUtils.mkdir_p path
	
	system("git clone https://git@github.com/socketry/#{name} #{path}")
	
	# I tried using `bundle config --local local.async ../` but it simply doesn't work.
	# system("bundle", "config", "--local", "local.async", __dir__, chdir: path)
	
	gemfile_paths = ["#{path}/Gemfile", "#{path}/gems.rb"]
	gemfile_path = gemfile_paths.find{|path| File.exist?(path)}
	
	File.open(gemfile_path, "a") do |file| 
		file.puts('gem "async", path: "../../"')
	end
	
	system("cd #{path} && bundle install && bundle exec #{command}") or abort("Tests for #{name} failed!")
end
