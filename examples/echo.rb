#!/usr/bin/env ruby

require 'async'
require 'async/tcp_socket'

SERVER_ADDRESS = Addrinfo.tcp('0.0.0.0', 9000)

def echo_server
	Async::Reactor.run do |task|
		# This is a synchronous block within the current task:
		Async::Socket.bind(SERVER_ADDRESS, backlog: 10) do |server|
			
			# This is an asynchronous block within the current reactor:
			task.reactor.with(*server.accept) do |client|
				data = client.read(512)
				
				task.sleep(rand)
				
				client.write(data)
			end while true
		end
	end
end

def echo_server2
	Async::Reactor.run do |task|
		puts "Binding to #{SERVER_ADDRESS.inspect}"
		# This is a synchronous block within the current task:
		Async::Socket.accept(SERVER_ADDRESS, backlog: 10) do |peer|
			task.reactor.with(peer) do |peer|
				data = peer.read(512)
				time = rand
				
				puts "Connection #{data} sleeping for #{time}s"
				task.sleep(time)
				
				peer.write(data)
				
				peer.io.shutdown
			end
		end
	end
end

def echo_client(data)
	Async::Reactor.run do |task|
		Async::Socket.connect(SERVER_ADDRESS) do |peer|
			peer.write(data)
			
			puts "echo_client: #{peer.read(512)}"
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
