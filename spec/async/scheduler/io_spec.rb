# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

require 'async/scheduler'
require 'io/nonblock'

RSpec.describe Async::Scheduler, if: Async::Scheduler.supported? do
	include_context Async::RSpec::Reactor
	
	describe ::IO do
		it "can wait with timeout" do
			expect(reactor).to receive(:io_wait).and_call_original
			
			s1, s2 = Socket.pair :UNIX, :STREAM, 0
			
			result = s1.wait_readable(0)
			
			expect(result).to be_nil
		ensure
			s1.close
			s2.close
		end
		
		it "can read a single character" do
			s1, s2 = Socket.pair :UNIX, :STREAM, 0
			
			child = reactor.async do
				c = s2.getc
				expect(c).to be == 'a'
			end
			
			s1.putc('a')
			
			child.wait
		end
		
		it "can perform blocking read" do
			s1, s2 = Socket.pair :UNIX, :STREAM, 0
			
			s1.nonblock = false
			s2.nonblock = false
			
			child = reactor.async do
				expect(s2.read(1)).to be == 'a'
				expect(s2.read(1)).to be == nil
			end
			
			sleep(0.1)
			s1.write('a')
			sleep(0.1)
			s1.close
			
			child.wait
		end
	end
end
