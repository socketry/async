# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2024, by Samuel Williams.

require "async/scheduler"
require "sus/fixtures/async"

describe Async::Scheduler do
	include Sus::Fixtures::Async::ReactorContext
	
	describe ::Addrinfo do
		it "can resolve addresses" do
			addresses = Addrinfo.getaddrinfo("www.google.com", "80")
			
			expect(addresses).not.to be(:empty?)
		end
		
		it "can resolve ipv4 addresses" do
			address = Addrinfo.getaddrinfo("127.0.0.1", "80").first
			
			expect(address.ipv4?).to be == true
		end
		
		it "can resolve ipv6 addresses" do
			address = Addrinfo.getaddrinfo("::1", "80").first
			
			expect(address.ipv6?).to be == true
		end
		
		it "can resolve ipv6 addresses with device suffix" do
			address = Addrinfo.getaddrinfo("::1%lo0", "80").first
			
			expect(address.ipv6?).to be == true
		end
		
		it "can resolve hostnames with device suffix" do
			addresses = Addrinfo.getaddrinfo("localhost%lo0", "80")
			
			expect(addresses).not.to be(:empty?)
		end
		
		it "raises an error for unknown hostnames" do
			expect do
				Addrinfo.getaddrinfo("async.invalid", "80")
			end.to raise_exception(SocketError)
		end
	end
	
	with "platform_resolver: false" do
		it "resolves with Resolv" do
			mock(::Resolv) do |mock|
				mock.replace(:getaddresses) do |hostname|
					["192.0.2.1"]
				end
			end
			
			default = Async::Scheduler.new(platform_resolver: false)
			expect(default.address_resolve("example.invalid")).to be == ["192.0.2.1"]
		ensure
			default&.close
		end
	end
	
	with "platform_resolver: true" do
		def resolve(hostname, platform_resolver: true)
			platform = Async::Scheduler.new(platform_resolver: platform_resolver)
			platform.address_resolve(hostname)
		ensure
			platform&.close
		end
		
		# Mocks are scoped to the current thread, but the lookup runs on its own thread, so replace `Addrinfo.getaddrinfo` globally. The block only sees lookups made without a fiber scheduler, i.e. on the resolver thread:
		def stub_getaddrinfo(stub)
			Addrinfo.singleton_class.alias_method(:original_getaddrinfo, :getaddrinfo)
			Addrinfo.define_singleton_method(:getaddrinfo) do |hostname, *arguments, **options|
				if Fiber.scheduler
					original_getaddrinfo(hostname, *arguments, **options)
				else
					stub.call(hostname, *arguments, **options)
				end
			end
			
			yield
		ensure
			Addrinfo.singleton_class.alias_method(:getaddrinfo, :original_getaddrinfo)
			Addrinfo.singleton_class.remove_method(:original_getaddrinfo)
		end
		
		it "resolves hostnames" do
			expect(resolve("localhost")).not.to be(:empty?)
		end
		
		it "strips a device suffix" do
			expect(resolve("localhost%lo0")).not.to be(:empty?)
		end
		
		it "raises an error for unknown hostnames" do
			expect do
				resolve("async.invalid")
			end.to raise_exception(SocketError)
		end
		
		it "resolves through Ruby's address_resolve hook" do
			lookups = Thread::Queue.new
			
			stub_getaddrinfo(->(hostname, *arguments, **options) do
				lookups << hostname
				Addrinfo.original_getaddrinfo(hostname, *arguments, **options)
			end) do
				thread = Thread.new do
					scheduler = Async::Scheduler.new(platform_resolver: true)
					Fiber.set_scheduler(scheduler)
					
					scheduler.run do
						Addrinfo.getaddrinfo("localhost", 80, nil, :STREAM)
					end.wait
				ensure
					Fiber.set_scheduler(nil)
				end
				
				addresses = thread.value
				
				expect(addresses).not.to be(:empty?)
				expect(addresses.map(&:ip_port).uniq).to be == [80]
				expect(lookups.size).to be == 1
				expect(lookups.pop).to be == "localhost"
			end
		end
		
		it "does not re-raise errors on the main thread when threads abort on exception" do
			abort_on_exception = Thread.abort_on_exception
			Thread.abort_on_exception = true
			
			expect do
				resolve("async.invalid")
			end.to raise_exception(SocketError)
			
			# An aborting thread raises asynchronously in the main thread; give it a chance to arrive:
			sleep(0.05)
		ensure
			Thread.abort_on_exception = abort_on_exception
		end
		
		it "exits the lookup's Ruby thread when the caller is stopped" do
			started = Thread::Queue.new
			
			platform = Async::Scheduler.new(platform_resolver: true)
			
			stub_getaddrinfo(->(hostname, *arguments, **options) do
				started << Thread.current
				sleep(10)
			end) do
				task = reactor.async do
					platform.address_resolve("slow.invalid")
				end
				
				lookup = started.pop
				task.stop
				
				# This only shows the Ruby thread exits; a native `getaddrinfo` call can't be interrupted and keeps running:
				expect(lookup.join(1)).to be == lookup
			end
		ensure
			platform&.close
		end
		
		it "limits the number of concurrent lookups" do
			mutex = Thread::Mutex.new
			active = 0
			maximum = 0
			
			platform = Async::Scheduler.new(platform_resolver: 2)
			
			stub_getaddrinfo(->(hostname, *arguments, **options) do
				mutex.synchronize{maximum = [maximum, active += 1].max}
				sleep(0.05)
				mutex.synchronize{active -= 1}
				Addrinfo.original_getaddrinfo("localhost", *arguments, **options)
			end) do
				tasks = 5.times.map do
					reactor.async{platform.address_resolve("slow.invalid")}
				end
				
				tasks.each{|task| expect(task.wait).not.to be(:empty?)}
			end
			
			expect(maximum).to be == 2
		ensure
			platform&.close
		end
		
		it "rejects a non-positive limit before allocating a selector" do
			mock(::IO::Event::Selector) do |mock|
				mock.replace(:new) do |*arguments|
					Kernel.raise "Allocated a selector for an invalid scheduler!"
				end
			end
			
			expect do
				Async::Scheduler.new(platform_resolver: 0)
			end.to raise_exception(ArgumentError)
		end
		
		it "does not block the event loop while resolving" do
			stub_getaddrinfo(->(hostname, *arguments, **options) do
				sleep(0.1)
				Addrinfo.original_getaddrinfo("localhost", *arguments, **options)
			end) do
				ticks = 0
				ticker = reactor.async do
					loop do
						ticks += 1
						sleep(0.01)
					end
				end
				
				expect(resolve("slow.invalid")).not.to be(:empty?)
				expect(ticks).to be >= 5
			ensure
				ticker&.stop
			end
		end
	end
end
