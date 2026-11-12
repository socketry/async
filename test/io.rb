# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2025, by Samuel Williams.
# Copyright, 2025, by Shopify Inc.

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
		it "closes the descriptor" do
			r, w = IO.pipe
			
			w.close
			
			expect(w).to be(:closed?)
			# The reader only sees the end of the stream once the descriptor is actually closed:
			expect(r.read).to be == ""
		ensure
			r&.close
		end
		
		it "closes the descriptor using the scheduler" do
			skip_unless_minimum_ruby_version("4.0")
			skip "The selector does not support io_close!" unless scheduler.respond_to?(:io_close)
			
			r, w = IO.pipe
			descriptor = w.fileno
			
			closed = []
			mock(scheduler) do |mock|
				mock.before(:io_close){|descriptor| closed << descriptor}
			end
			
			w.close
			
			expect(closed).to be(:include?, descriptor)
			expect(w).to be(:closed?)
			expect(r.read).to be == ""
		ensure
			r&.close
		end
		
		it "closes the descriptor while the scheduler is terminating" do
			r, w = IO.pipe
			
			Thread.new do
				Sync do
					# This task is still running when the scheduler exits, so the descriptor is closed during termination, just before the selector itself is closed:
					Async(transient: true) do
						sleep
					ensure
						w.close
					end
				end
			end.join
			
			expect(w).to be(:closed?)
			expect(r.read).to be == ""
		ensure
			r&.close
		end
		
		it "can interrupt reading fiber when closing" do
			skip_unless_minimum_ruby_version("3.5")
			
			r, w = IO.pipe
			
			read_task = Async do
				expect do
					r.read(5)
				end.to raise_exception(IOError, message: be =~ /stream closed/)
			end
			
			r.close
			read_task.wait
		end
		
		it "can interrupt reading fiber when closing from another fiber" do
			skip_unless_minimum_ruby_version("3.5")
			
			r, w = IO.pipe
			
			read_task = Async do
				expect do
					r.read(5)
				end.to raise_exception(IOError, message: be =~ /stream closed/)
			end
			
			close_task = Async do
				r.close
			end
			
			close_task.wait
			read_task.wait
		end
		
		it "can interrupt reading fiber when closing from a new thread" do
			skip_unless_minimum_ruby_version("3.5")
			
			r, w = IO.pipe
			
			read_task = Async do
				expect do
					r.read(5)
				end.to raise_exception(IOError, message: be =~ /stream closed/)
			end
			
			close_thread = Thread.new do
				r.close
			end
			
			close_thread.value
			read_task.wait
		end
		
		it "can interrupt reading fiber when closing from a fiber in a new thread" do
			skip_unless_minimum_ruby_version("3.5")
			
			r, w = IO.pipe
			
			read_task = Async do
				expect do
					r.read(5)
				end.to raise_exception(IOError, message: be =~ /stream closed/)
			end
			
			close_thread = Thread.new do
				close_task = Async do
					r.close
				end
				close_task.wait
			end
			
			close_thread.value
			read_task.wait
		end
		
		it "can interrupt reading thread when closing from a fiber" do
			skip_unless_minimum_ruby_version("3.5")
			
			r, w = IO.pipe
			
			read_thread = Thread.new do
				Thread.current.report_on_exception = false
				r.read(5)
			end
			
			# Wait until read_thread blocks on I/O
			Thread.pass until read_thread.status == "sleep"
			
			close_task = Async do
				r.close
			end
			
			close_task.wait
			
			expect do
				read_thread.join
			end.to raise_exception(IOError, message: be =~ /closed/)
		end
		
		it "can interrupt reading fiber in a new thread when closing from a fiber" do
			skip_unless_minimum_ruby_version("3.5")
			
			r, w = IO.pipe
			
			read_thread = Thread.new do
				Thread.current.report_on_exception = false
				read_task = Async do
					expect do
						r.read(5)
					end.to raise_exception(IOError, message: be =~ /closed/)
				end
				read_task.wait
			end
			
			# Wait until read_thread blocks on I/O
			Thread.pass until read_thread.status == "sleep"
			
			close_task = Async do
				r.close
			end
			close_task.wait
			
			read_thread.value
		end
	end
	
	describe ".select" do
		it "can select readable IO" do
			expect(Fiber.scheduler).to receive(:io_select)
			
			input, output = IO.pipe
			
			begin
				# Write some data to make it readable
				output.write("Hello World")
				output.flush
				
				readables, writables, errorables = IO.select([input], nil, nil, 0.1)
				
				expect(readables).to have_value(be == input)
				expect(writables).to be(:empty?)
				expect(errorables).to be(:empty?)
			ensure
				input.close
				output.close
			end
		end
		
		it "can select writable IO" do
			expect(Fiber.scheduler).to receive(:io_select)
			
			input, output = IO.pipe
			
			begin
				readables, writables, errorables = IO.select(nil, [output], nil, 0.1)
				
				expect(readables).to be(:empty?)
				expect(writables).to have_value(be == output)
				expect(errorables).to be(:empty?)
			ensure
				input.close
				output.close
			end
		end
	end
end
