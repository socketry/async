# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "sus/fixtures/async"
require "sus/fixtures/agent/context"

describe "context/thread-safety.md" do
	include Sus::Fixtures::Agent::Context
	
	let(:context_path)  {File.expand_path("../../..", __dir__)}
	let(:path) {File.join(context_path, subject)}
	
	it "can be used to test thread safety" do
		with_agent_context(path) do |context|
			response = context.call(<<~PROMPT)
				Is the following code thread-safe? Start your response with "yes" or "no".
				
				```ruby
				while @pool.busy?
					@pool.wait
				end
				```
			PROMPT
			
			expect(response).to be =~ /\Ano/i
		end
	end
	
	it "can be used to test thread safety" do
		with_agent_context(path) do |context|
			response = context.call(<<~PROMPT)
				Is the following code thread-safe? Start your response with "yes" or "no".
				
				```ruby
				# array is not shared.
				array.sort!
				```
			PROMPT
			
			expect(response).to be =~ /\Ayes/i
		end
	end
	
	it "can be used to test thread safety" do
		with_agent_context(path) do |context|
			response = context.call(<<~PROMPT)
				Is the following code thread-safe? Start your response with "yes" or "no".
				
				```ruby
				class Loader
					def self.data
						@data ||= JSON.load_file('data.json')
					end
				end
				```
			PROMPT
			
			expect(response).to be =~ /\Ano/i
		end
	end
end
