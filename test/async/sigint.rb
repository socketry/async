# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "open3"
require "rbconfig"

describe "Async::SIGINT" do
	let(:ruby_binary) {RbConfig.ruby}
	let(:load_path) {File.expand_path("../../lib", __dir__)}
	
	def capture_ruby(*arguments)
		Open3.capture3(ruby_binary, "-I#{load_path}", *arguments)
	end
	
	it "requires the SIGINT compatibility handler" do
		script = <<~RUBY
			require "async/sigint"
			
			sigint = Async.const_get(:SIGINT)
			
			puts sigint.required?
		RUBY
		
		output, error, status = capture_ruby("-e", script)
		
		expect(error).to be == ""
		expect(status).to be(:success?)
		expect(output.lines(chomp: true)).to be == ["true"]
	end
	
	it "does not replace an existing SIGINT handler" do
		script = <<~RUBY
			handled = Thread::Queue.new
			
			Signal.trap(:INT) do
				handled.push(true)
			end
			
			require "async/sigint"
			
			Process.kill(:INT, Process.pid)
			
			puts handled.pop
		RUBY
		
		output, error, status = capture_ruby("-e", script)
		
		expect(error).to be == ""
		expect(status).to be(:success?)
		expect(output.lines(chomp: true)).to be == ["true"]
	end
	
	it "defers SIGINT while signal exceptions are masked" do
		script = <<~RUBY
			require "async"
			
			waiting = Thread::Queue.new
			release = Thread::Queue.new
			inner = false
			
			Thread.new do
				waiting.pop
				Process.kill(:INT, Process.pid)
				release.push(true)
			end
			
			begin
				Thread.handle_interrupt(SignalException => :never) do
					begin
						waiting.push(true)
						release.pop
					rescue Interrupt
						inner = true
						raise
					end
				end
			rescue Interrupt
				puts "outer"
			end
			
			puts inner
		RUBY
		
		output, error, status = capture_ruby("-e", script)
		
		expect(error).to be == ""
		expect(status).to be(:success?)
		expect(output.lines(chomp: true)).to be == ["outer", "false"]
	end
end
