
if ENV['COVERAGE'] || ENV['TRAVIS']
	begin
		require 'simplecov'
		
		SimpleCov.start do
			add_filter "/spec/"
		end
		
		if ENV['TRAVIS']
			require 'coveralls'
			Coveralls.wear!
		end
	rescue LoadError
		warn "Could not load simplecov: #{$!}"
	end
end

require "bundler/setup"
require "async"
require "async/tcp_socket"
require "async/udp_socket"

RSpec.shared_context "closes all io" do
	def current_ios(gc: GC.start)
		all_ios = ObjectSpace.each_object(IO).to_a.sort_by(&:object_id)
		
		# We are not interested in ios that have been closed already:
		return all_ios.reject{|io| io.closed?}
	end
	
	# We use around(:each) because it's the highest priority.
	around(:each) do |example|
		@system_ios = current_ios
		
		result = example.run
		
		expect(current_ios).to be == @system_ios
		
		result
	end
end

RSpec.shared_context "reactor" do
	let(:reactor) {Async::Task.current.reactor}
	
	around(:each) do |example|
		Async::Reactor.run do
			result = example.run
			
			return result if result.is_a? Exception
		end
	end
	
	include_context "closes all io"
end

RSpec.configure do |config|
	# Enable flags like --only-failures and --next-failure
	config.example_status_persistence_file_path = ".rspec_status"

	config.expect_with :rspec do |c|
		c.syntax = :expect
	end
end
