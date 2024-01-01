# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'sus/fixtures/async'

describe IO do
	include Sus::Fixtures::Async::ReactorContext
	
	describe '.pipe' do
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
			input, output = IO.pipe
			input.timeout = 0.001
			
			expect do
				line = input.gets
			end.to raise_exception(::IO::TimeoutError)
		end
		
		it "can wait readable with default timeout" do
			input, output = IO.pipe
			input.timeout = 0.001
			
			expect do
				# This behaviour is not consistent with non-fiber scheduler IO.
				# However, this is the best we can do without fixing CRuby.
				input.wait_readable
			end.to raise_exception(::IO::TimeoutError)
		end
		
		it "can wait readable with 0 timeout" do
			input, output = IO.pipe
			
			expect(input.wait_readable(0)).to be_nil
		end
	end
end
