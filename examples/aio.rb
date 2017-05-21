#!/usr/bin/env ruby

require 'async'
require 'async/tcp_socket'

reactor = Async::Reactor.new

puts "Creating server"
server = TCPServer.new("localhost", 6777)

REPEATS = 10

timer = reactor.after(1) do
	puts "Reactor timed out!"
	reactor.stop
end

reactor.async(server) do |server, task|
	REPEATS.times do |i|
		puts "Accepting peer on server #{server}"
		task.with(server.accept) do |peer|
			puts "Sending data to peer"
			
			peer.write "data #{i}"
		end
	end
	
	puts "Server finished, canceling timer"
	timer.cancel
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

reactor.run
