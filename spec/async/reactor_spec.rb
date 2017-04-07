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
	describe 'basic tcp server' do
		include_context "reactor"
		
		let(:port) {6778}
		
		# These may block:
		let(:server) {TCPServer.new("localhost", port)}
		let(:client) {TCPSocket.new("localhost", port)}
		
		let(:data) {"The quick brown fox jumped over the lazy dog."}
		
		it "should start server and send data" do
			subject.async(server) do |server, task|
				task.with(server.accept) do |peer|
					peer.write(peer.read(512))
				end
			end
			
			subject.async(client) do |client|
				client.write(data)
				
				expect(client.read(512)).to be == data
			end
			
			subject.run
		end
	end
	
	describe 'non-blocking tcp connect' do
		include_context "reactor"
		
		let(:port) {6779}
		
		# These may block:
		let(:server) {TCPServer.new("localhost", port)}
		
		let(:data) {"The quick brown fox jumped over the lazy dog."}
		
		it "should start server and send data" do
			subject.async(server) do |server, task|
				task.with(server.accept) do |peer|
					peer.write(peer.read(512))
				end
			end
			
			subject.async do |task|
				Async::Wrap::TCPSocket.connect("localhost", port) do |client|
					client.write(data)
					expect(client.read(512)).to be == data
				end
			end
			
			subject.run
		end
	end
	
	describe 'basic udp server' do
		include_context "reactor"
		
		let(:port) {6776}
		
		# These may block:
		let(:server) {UDPSocket.new.tap{|socket| socket.bind("localhost", port)}}
		let(:client) {UDPSocket.new}
		
		let(:data) {"The quick brown fox jumped over the lazy dog."}
		
		it "should echo data back to peer" do
			subject.async(server) do |server, task|
				packet, (_, remote_port, remote_host) = server.recvfrom(512)
				
				reactor.async do
					server.send(packet, 0, remote_host, remote_port)
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
