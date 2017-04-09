#!/usr/bin/env ruby

require 'async'
require 'async/tcp_socket'

def echo_server
	Async::Reactor.run do |task|
		# This is a synchronous block within the current task:
		task.with(TCPServer.new('localhost', 9000)) do |server|
			
			# This is an asynchronous block within the current reactor:
			task.reactor.with(server.accept) do |client|
				data = client.read(512)
				
				task.sleep(rand)
				
				client.write(data)
			end while true
		end
	end
end

def echo_client(data)
	Async::Reactor.run do |task|
		Async::TCPServer.connect('localhost', 9000) do |socket|
			socket.write(data)
			puts "echo_client: #{socket.read(512)}"
		end
	end
end

Async::Reactor.run do
	server = echo_server
	
	5.times.collect do |i|
		echo_client("Hello World #{i}")
	end.each(&:wait)
	
	server.stop
end
