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
end

include Async::Methods

async def count_chickens(area_name)
	10.times do |i|
		sleep rand
		
		puts "Found a chicken in the #{area_name}!"
	end
end

async def count_all_chckens
	count_chickens("garden")
	count_chickens("house")
	count_chickens("tree")
end

count_all_chckens
