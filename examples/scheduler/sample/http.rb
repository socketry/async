#!/usr/bin/env ruby

require_relative '../../lib/async'
require_relative '../../lib/async/barrier'

require 'net/http'

terms = ["ruby", "rust", "python", "basic", "clojure"]

Async do
	barrier = Async::Barrier.new
	
	terms.each do |term|
		barrier.async do |task|
			Console.logger.info(task, "Fetching #{term}")
			
			response = Net::HTTP.get(URI "https://www.google.com/search?q=#{term}")
			
			term_count = response.scan(term).size
			Console.logger.info(task, "Found #{term_count} times")
		end
	end
	
	barrier.wait
end
