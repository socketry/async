#!/usr/bin/env ruby

require_relative '../../lib/async'
require_relative '../../lib/async/barrier'

require 'net/http'

terms = ['cats', 'dogs', 'sheep', 'cows']

Async do
	barrier = Async::Barrier.new
	
	terms.each do |term|
		barrier.async do
			Console.logger.info "Searching for #{term}"
			
			response = Net::HTTP.get(URI "https://www.google.com/search?q=#{term}")
			
			count = response.scan(term).count
			
			Console.logger.info "Found #{term} #{count} times!"
		end
	end
	
	barrier.wait
end
