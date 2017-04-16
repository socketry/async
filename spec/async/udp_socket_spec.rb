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

RSpec.describe Async::Reactor do
	# Shared port for localhost network tests.
	let(:port) {6778}
	
	describe 'basic udp server' do
		# These may block:
		let(:server) {UDPSocket.new.tap{|socket| socket.bind("localhost", port)}}
		let(:client) {UDPSocket.new}
		
		let(:data) {"The quick brown fox jumped over the lazy dog."}
		
		after(:each) do
			server.close
		end
		
		it "should echo data back to peer" do
			subject.async(server) do |server|
				server.recvfrom_each(512) do |packet, (_, remote_port, remote_host)|
					server.send(packet, 0, remote_host, remote_port)
					
					break
				end
			end
			
			subject.async(client) do |client|
				client.send(data, 0, "localhost", port)
				
				response, _ = client.recvfrom(512)
				
				expect(response).to be == data
			end
			
			subject.run
		end
	end
end
