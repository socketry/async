# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/async"
require "async"

describe Process do
	describe ".fork" do
		it "can fork with block form" do
			r, w = IO.pipe
			
			Async do
				pid = Process.fork do
					# Child process:
					w.write("hello")
				end
				
				# Parent process:
				w.close
				expect(r.read).to be == "hello"
			ensure
				Process.waitpid(pid) if pid
			end
		end
		
		it "can fork with non-block form" do
			r, w = IO.pipe
			
			Async do
				unless pid = Process.fork
					# Child process:
					w.write("hello")
					
					exit!
				end
				
				# Parent process:
				w.close
				expect(r.read).to be == "hello"
			ensure
				Process.waitpid(pid) if pid
			end
		end
	end
end
