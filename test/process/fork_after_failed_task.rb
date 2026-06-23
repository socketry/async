# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "sus/fixtures/async"
require "async"

describe "fork after failed task" do
	after do
		Fiber.set_scheduler(nil)
	end
	
	it "runs a failed task status check first" do
		reactor = Async::Reactor.new
		
		reactor.run do
			task = reactor.async do
				raise "Test failure"
			end
			
			begin
				task.wait
			rescue RuntimeError
				# Expected.
			end
			
			expect(task.status).to be == :failed
			expect(task.failed?).to be == true
		end
	end
	
	it "can fork with block form" do
		r, w = IO.pipe
		
		Async do
			pid = Process.fork do
				w.write("hello")
			end
			
			w.close
			expect(r.read).to be == "hello"
		ensure
			Fiber.blocking do
				$stderr.puts "Waiting for child process #{pid} to exit... (#{$!})"
			end
			Process.waitpid(pid) if pid
		end
	end
end
