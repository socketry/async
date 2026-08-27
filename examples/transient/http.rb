#!/usr/bin/env ruby

require 'async'
require 'async/http/internet'

Async do |task|
	internet = Async::HTTP::Internet.new
	
	response = internet.get("https://www.google.com/search?q=ruby")
	response.finish
	
	task.reactor.print_hierarchy
	
	Async(transient: true) do |task|
		while true
			task.sleep
		end
	ensure
		internet&.close
	end
end

puts "Finished"