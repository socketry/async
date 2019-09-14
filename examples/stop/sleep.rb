#!/usr/bin/env ruby

require_relative '../../lib/async'

require 'async/http/endpoint'
require 'async/http/server'

require 'async/http/internet'

# To query the web server:
# curl http://localhost:9292/kittens

Async do |parent|
	endpoint = Async::HTTP::Endpoint.parse("http://localhost:9292")
	internet = Async::HTTP::Internet.new
	
	server = Async::HTTP::Server.for(endpoint) do |request|
		if request.path =~ /\/(.*)/
			keyword = $1
			
			response = internet.get("https://www.google.com/search?q=#{keyword}")
			
			count = response.read.scan(keyword).size
			
			Protocol::HTTP::Response[200, [], ["Google found #{count} instance(s) of #{keyword}.\n"]]
		else
			Protocol::HTTP::Response[404, [], []]
		end
	end
	
	tasks = server.run
	
	#while true
	parent.sleep(10)
	parent.reactor.print_hierarchy
	#end
	
	parent.stop # -> Async::Stop
	
	tasks.each(&:stop)
end
