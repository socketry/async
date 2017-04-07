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

require_relative 'socket'

module Async
	# Asynchronous TCP socket/client.
	class TCPSocket < IPSocket
		wraps ::TCPSocket
		
		def self.connect(remote_address, remote_port, local_address = nil, local_port = nil, task: Task.current, &block)
			# This may block if remote_address is a hostname
			remote = Addrinfo.tcp(remote_address, remote_port)
			
			socket = ::Socket.new(remote.afamily, ::Socket::SOCK_STREAM, 0)
			socket.bind Addrinfo.tcp(local_address, local_port) if local_address
			
			if block_given?
				task.with(socket) do |wrapper|
					wrapper.connect(remote.to_sockaddr)
					
					yield wrapper
				end
			else
				task.bind(socket).connect(remote.to_sockaddr)
				
				return socket
			end
		end
	end
	
	# Asynchronous TCP server
	class TCPServer < TCPSocket
		wraps ::TCPServer
	end
end

