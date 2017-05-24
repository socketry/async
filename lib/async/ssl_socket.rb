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

module OpenSSL
  module SSL
    class SSLServer
      def accept_nonblock **opts
        # Socket#accept returns [socket, addrinfo].
        # TCPServer#accept returns a socket.
        # The following comma strips addrinfo.
        sock, = @svr.accept_nonblock
        begin
          ssl = OpenSSL::SSL::SSLSocket.new(sock, @ctx)
          ssl.sync_close = true
          ssl.accept_nonblock(opts)
          ssl
        rescue Exception => ex
          if ssl
            ssl.close
          else
            sock.close
          end
          raise ex
        end
      end
      def fileno
        to_io.fileno
      end
    end
  end
end
module Async
	# Asynchronous TCP socket wrapper.
	class SSLSocket < IPSocket
		wraps OpenSSL::SSL::SSLSocket
	end
	
	# Asynchronous TCP server wrappper.
	class SSLServer < SSLSocket
		wraps OpenSSL::SSL::SSLServer
		
		wrap_blocking_method :accept, :accept_nonblock
	end
end
