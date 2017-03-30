#!/usr/bin/env ruby

require 'async'

reactor = Async::Reactor.new

puts "Creating server"
server = TCPServer.new("localhost", 6777)

REPEATS = 10

reactor.async(server) do |server|
	REPEATS.times do |i|
		puts "Accepting peer on server #{server}"
		peer = server.accept
		
		puts "Sending data to peer"
		peer << "data #{i}"
		peer.shutdown
	end
	
	puts "Server finished"
end

REPEATS.times do |i|
	# This aspect of the connection is synchronous.
	puts "Creating client #{i}"
	client = TCPSocket.new("localhost", 6777)
	
	reactor.async(client) do |client|
		puts "Reading data on client #{i}"
		puts client.read(1024)
	end
end

reactor.timers.after(1) do
	puts "Reactor timed out!"
	reactor.stop
end

reactor.run_forever
