# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require_relative 'io'

require 'socket'

module Async
	class BasicSocket < IO
		wraps ::BasicSocket
		
		wrap_blocking_method :recv, :recv_nonblock
		wrap_blocking_method :recvmsg, :recvmsg_nonblock
		wrap_blocking_method :send, :sendmsg_nonblock
		wrap_blocking_method :sendmsg, :sendmsg_nonblock
	end
	
	class Socket < BasicSocket
		wraps ::Socket
		
		include ::Socket::Constants
		
		wrap_blocking_method :accept, :accept_nonblock
		
		wrap_blocking_method :connect, :connect_nonblock do |*args|
			begin
				async_send(:connect_nonblock, *args)
			rescue Errno::EISCONN
				# We are now connected.
			end
		end
		
		# Establish a connection to a given `remote_address`.
		# @example
		#  socket = Async::Socket.connect(Addrinfo.tcp("8.8.8.8", 53))
		# @param remote_address [Addrinfo] The remote address to connect to.
		# @param local_address [Addrinfo] The local address to bind to before connecting.
		# @option protcol [Integer] The socket protocol to use.
		def self.connect(remote_address, local_address = nil, protocol: 0, task: Task.current)
			socket = ::Socket.new(remote_address.afamily, remote_address.socktype, protocol)
			
			if local_address
				socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
				socket.bind(local_address) if local_address
			end
			
			if block_given?
				task.with(socket) do |wrapper|
					wrapper.connect(remote_address.to_sockaddr)
					
					yield wrapper
				end
			else
				task.bind(socket).connect(remote_address.to_sockaddr)
				
				return socket
			end
		end
		
		# Bind to a local address and listen for incoming connections.
		# @example
		#  socket = Async::Socket.listen(Addrinfo.tcp("0.0.0.0", 9090))
		# @param local_address [Addrinfo] The local address to bind to.
		# @option protcol [Integer] The socket protocol to use.
		def self.listen(local_address, backlog: 128, protocol: 0, task: Task.current, &block)
			socket = ::Socket.new(local_address.afamily, local_address.socktype, protocol)
			
			socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
			socket.bind(local_address)
			
			socket.listen(128)
			
			if block_given?
				task.with(socket, &block)
			else
				return socket
			end
		end
		
		def self.accept(*args, task: Task.current, &block)
			listen(*args, task: task) do |wrapper|
				task.with(*wrapper.accept, &block) while true
			end
		end
	end
	
	class IPSocket < BasicSocket
		wraps ::IPSocket
	end
end
