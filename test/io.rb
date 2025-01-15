# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "sus/fixtures/async"

describe IO do
	include Sus::Fixtures::Async::ReactorContext
	
	describe ".pipe" do
		let(:message) {"Helloooooo World!"}
		
		it "can send message via pipe" do
			input, output = IO.pipe
			
			reactor.async do
				sleep(0.001)
				
				message.each_char do |character|
					output.write(character)
				end
				
				output.close
			end
			
			expect(input.read).to be == message
			
		ensure
			input.close
			output.close
		end
		
		it "can read with timeout" do
			skip_unless_constant_defined(:TimeoutError, IO)
			
			input, output = IO.pipe
			input.timeout = 0.001
			
			expect do
				line = input.gets
			end.to raise_exception(::IO::TimeoutError)
		end
		
		it "can write with timeout" do
			skip_unless_constant_defined(:TimeoutError, IO)
			
			big = "x" * 1024 * 1024
			
			input, output = IO.pipe
			output.timeout = 0.001
			
			expect do
				while true
					output.write(big)
				end
			end.to raise_exception(::IO::TimeoutError)
		end
		
		it "can wait readable with default timeout" do
			skip_unless_constant_defined(:TimeoutError, IO)
			
			input, output = IO.pipe
			input.timeout = 0.001
			
			expect do
				# This behaviour is not consistent with non-fiber scheduler IO.
				# However, this is the best we can do without fixing CRuby.
				input.wait_readable
			end.to raise_exception(::IO::TimeoutError)
		end
		
		it "can wait readable with explicit timeout" do
			input, output = IO.pipe
			
			expect(input.wait_readable(0)).to be_nil
		end
	end
	
	describe "/dev/null" do
		# Ruby < 3.3.1 will fail this test with the `io_write` scheduler hook enabled, as it will try to io_wait on /dev/null which will fail on some platforms (kqueue).
		it "can write to /dev/null" do
			out = File.open("/dev/null", "w")
			
			# Needs to write about 8,192 bytes to trigger the internal flush:
			1000.times do
				out.puts "Hello World!"
			end
		ensure
			out.close
		end
	end
	
	with "#close" do
		it "can interrupt reading fiber when closing" do
			r, w = IO.pipe
			
			read_task = Async do
				r.read(5)
				nil
			rescue IOError => e
				e.to_s
			end

			r.close

			expect(read_task.wait).to be == 'closed stream'
		end

		it "can interrupt reading fiber when closing from another fiber" do
			r, w = IO.pipe

			read_task = Async do
				r.read(5)
				nil
			rescue IOError => e
				e.to_s
			end

			close_task = Async do
				r.close
			end

			close_task.wait
			expect(read_task.wait).to be == 'closed stream'
		end

		it "can interrupt reading fiber when closing from a new thread" do
			r, w = IO.pipe

			read_task = Async do
				r.read(5)
				nil
			rescue IOError => e
				e.to_s
			end

			close_thread = Thread.new do
				r.close
			end

			close_thread.value
			expect(read_task.wait).to be == 'closed stream'
		end

		it "can interrupt reading fiber when closing from a fiber in a new thread" do
			r, w = IO.pipe

			read_task = Async do
				r.read(5)
				nil
			rescue IOError => e
				e.to_s
			end

			close_thread = Thread.new do
				close_task = Async do
					r.close
				end
				close_task.wait
			end

			close_thread.value
			expect(read_task.wait).to be == 'closed stream'
		end

		it "can interrupt reading thread when closing from a fiber" do
			r, w = IO.pipe

			read_thread = Thread.new do
				Thread.current.report_on_exception = false
				r.read(5)
				nil
			rescue IOError => e
				e.to_s
			end

			# Wait until read_thread blocks on I/O
			while read_thread.status != 'sleep'
				sleep(0.001)
			end

			close_task = Async do
				r.close
			end

			close_task.wait
			expect(read_thread.value).to be == 'closed stream'
		end

		it "can interrupt reading fiber in a new thread when closing from a fiber" do
			r, w = IO.pipe

			read_thread = Thread.new do
				Thread.current.report_on_exception = false
				read_task = Async do
					r.read(5)
					nil
				rescue IOError => e
					e.to_s
				end
				read_task.wait
			end

			# Wait until read_thread blocks on I/O
			while read_thread.status != 'sleep'
				sleep(0.001)
			end

			close_task = Async do
				r.close
			end
			close_task.wait

			expect(read_thread.value).to be == 'closed stream'
		end
	end
end
