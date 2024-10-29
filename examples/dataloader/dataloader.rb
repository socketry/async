# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2024, by Samuel Williams.

require "net/http"
require "uri"

class Dataloader
	def initialize
		@loading = 0
		@results = Thread::Queue.new
	end
	
	def load(url)
		@loading += 1
		Fiber.schedule do
			puts "Making request to #{url}"
			result = Net::HTTP.get(URI url)
		ensure
			puts "Finished making request to #{url}."
			@loading -= 1
			@results << result
		end
	end
	
	def wait
		raise RuntimeError if @loading == 0
		
		return @results.pop
	end
	
	def wait_all
		raise RuntimeError if @loading == 0
		
		results = []
		results << @results.pop until @loading == 0
		
		return results
	end
end
