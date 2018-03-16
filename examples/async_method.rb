#!/usr/bin/env ruby

require_relative '../lib/async'

module Async::Methods
	def sleep(*args)
		Async::Task.current.sleep(*args)
	end

	def async(name)
		original_method = self.method(name)
		
		define_method(name) do |*args|
			Async::Reactor.run do |task|
				original_method.call(*args)
			end
		end
	end

	def await(&block)
		block.call.wait
	end
	
	def barrier!
		Async::Task.current.children.each(&:wait)
	end
end

include Async::Methods

async def count_chickens(area_name)
	3.times do |i|
		sleep rand
		
		puts "Found a chicken in the #{area_name}!"
	end
end

async def find_chicken(areas)
	puts "Searching for chicken..."
	
	sleep rand * 5
	
	return areas.sample
end

async def count_all_chckens
	# These methods all run at the same time.
	count_chickens("garden")
	count_chickens("house")
	count_chickens("tree")
	
	# Wait for all previous async work to complete...
	barrier!
	
	puts "There was a chicken in the #{find_chicken(["garden", "house", "tree"]).wait}"
end

count_all_chckens
