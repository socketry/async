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
	include_context "closes all io"
	
	# Shared port for localhost network tests.
	let(:port) {6779}
	
	around(:each) do |example|
		# Accept a single incoming connection and then finish.
		subject.async do |task|
			Async::Socket.listen(server_address) do |server|
				task.with(*server.accept) do |peer, address|
					data = peer.read(512)
					peer.write(data)
				end
			end
		end
		
		result = example.run
		
		return result if result.is_a? Exception
		
		subject.run
	end
	
	describe 'basic tcp server' do
		# These may block:
		let(:server_address) {Addrinfo.tcp("localhost", port)}
		
		let(:data) {"The quick brown fox jumped over the lazy dog."}
		
		it "should start server and send data" do
			subject.async do
				Async::Socket.connect(server_address) do |client|
					client.write(data)
					expect(client.read(512)).to be == data
				end
			end
		end
	end
	
	describe 'non-blocking tcp connect' do
		# These may block:
		let(:server) {TCPServer.new("localhost", port)}
		let(:server_address) {Addrinfo.tcp("localhost", port)}
		
		let(:data) {"The quick brown fox jumped over the lazy dog."}
		
		it "should start server and send data" do
			subject.async do |task|
				Async::Socket.connect(server_address) do |client|
					client.write(data)
					expect(client.read(512)).to be == data
				end
			end
		end
		
		it "can connect socket and read/write in a different task" do
			socket = nil
			
			subject.async do |task|
				socket = Async::Socket.connect(server_address)
				
				# Stop the reactor once the connection was made.
				subject.stop
			end
		
			subject.run
			
			expect(socket).to_not be_nil
			
			subject.async(socket) do |client|
				client.write(data)
				expect(client.read(512)).to be == data
			end
			
			subject.run
		end
		
		it "can't use a socket in nested tasks" do
			subject.async do |task|
				socket = Async::Socket.connect(server_address)
				
				# I'm not sure if this is the right behaviour or not. Without a significant amont of work, async sockets are tied to the task that creates them.
				expect do
					subject.async(socket) do |client|
						client.write(data)
						expect(client.read(512)).to be == data
					end
				end.to raise_error(ArgumentError, /already registered with selector/)
				
				# We need to explicitly close the socket, since we explicitly opened it.
				socket.close
			end
		end
	end
end
