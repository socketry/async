# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

require 'async/rspec'

RSpec.describe IO do
	include_context Async::RSpec::Reactor

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
	end
end
