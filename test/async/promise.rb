# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require "async/promise"

require "sus/fixtures/async"

describe Async::Promise do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:promise) { subject.new }
	
	it "starts as unresolved" do
		expect(promise.resolved?).to be == false
		expect(promise.waiting?).to be == false
		expect(promise.value).to be_nil
	end
	
	it "returns immediately when already resolved" do
		promise.resolve(:immediate)
		
		# Multiple waits should return immediately:
		expect(promise.wait).to be == :immediate
		expect(promise.wait).to be == :immediate
	end
	
	with "#resolve" do
		it "can be resolved with a value" do
			promise.resolve(:success)
			
			expect(promise.resolved?).to be == true
			expect(promise.value).to be == :success
			expect(promise.wait).to be == :success
		end
		
		it "ignores subsequent resolve calls" do
			promise.resolve(:first)
			promise.resolve(:second)
			
			expect(promise.value).to be == :first
			expect(promise.wait).to be == :first
		end
		
		it "ignores reject after resolve" do
			promise.resolve(:success)
			promise.reject(StandardError.new("ignored"))
			
			expect(promise.wait).to be == :success
		end
	end
	
	with "#reject" do
		it "can be rejected with an exception" do
			error = StandardError.new("test error")
			promise.reject(error)
			
			expect(promise.resolved?).to be == true
			expect(promise.value).to be == error
			
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /test error/)
		end
		
		it "ignores subsequent reject calls" do
			error1 = StandardError.new("first error")
			error2 = StandardError.new("second error")
			
			promise.reject(error1)
			promise.reject(error2)
			
			expect(promise.value).to be == error1
			
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /first error/)
		end
		
		it "ignores resolve after reject" do
			error = StandardError.new("error")
			promise.reject(error)
			promise.resolve(:ignored)
			
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /error/)
		end
	end
	
	with "#wait" do

		it "blocks until resolved" do
			result = nil
			
			waiter = reactor.async do
				result = promise.wait
			end
			
			# Waiter should be blocked:
			expect(promise.waiting?).to be == true
			expect(result).to be_nil
			
			# Resolve and wait for completion:
			promise.resolve(:delayed_result)
			waiter.wait
			
			expect(result).to be == :delayed_result
			expect(promise.waiting?).to be == false
		end
		
		it "blocks until rejected" do
			error = nil
			
			waiter = reactor.async do
				promise.wait
			rescue => caught_error
				error = caught_error
			end
			
			# Waiter should be blocked:
			expect(promise.waiting?).to be == true
			expect(error).to be_nil
			
			# Reject and wait for completion:
			test_error = StandardError.new("delayed error")
			promise.reject(test_error)
			waiter.wait
			
			expect(error).to be == test_error
			expect(promise.waiting?).to be == false
		end
		
		it "handles multiple concurrent waiters" do
			results = []
			errors = []
			
			# Start multiple waiters:
			waiters = 3.times.map do |i|
				reactor.async do
					begin
						results << promise.wait
					rescue => error
						errors << error
					end
				end
			end
			
			# All should be waiting:
			expect(promise.waiting?).to be == true
			
			# Resolve - all waiters should get the same result:
			promise.resolve(:shared_result)
			waiters.each(&:wait)
			
			expect(results).to be == [:shared_result, :shared_result, :shared_result]
			expect(errors).to be(:empty?)
			expect(promise.waiting?).to be == false
		end
		
		it "handles multiple concurrent waiters with rejection" do
			results = []
			errors = []
			
			# Start multiple waiters:
			waiters = 3.times.map do |i|
				reactor.async do
					begin
						results << promise.wait
					rescue => error
						errors << error
					end
				end
			end
			
			# All should be waiting:
			expect(promise.waiting?).to be == true
			
			# Reject - all waiters should get the same error:
			test_error = StandardError.new("shared error")
			promise.reject(test_error)
			waiters.each(&:wait)
			
			expect(results).to be(:empty?)
			expect(errors.size).to be == 3
			expect(errors).to be(:all?) { |error| error == test_error }
			expect(promise.waiting?).to be == false
		end
	end
	
	with "signal alias" do
		it "signal behaves like resolve" do
			promise.signal(:aliased_value)
			
			expect(promise.resolved?).to be == true
			expect(promise.wait).to be == :aliased_value
		end
	end
	
	with "warning suppression" do
		it "can suppress warnings for expected failures" do
			promise.suppress_warnings!
			
			expect(promise.waiting?).to be == true
			
			# Promise should still appear to have waiters after rejection due to suppression:
			promise.reject(StandardError.new("expected failure"))
			expect(promise.waiting?).to be == true  # Artificial count still there
		end
	end
	
	with "#fulfill" do
		it "resolves with the result of a successful block" do
			result = promise.fulfill do
				:block_result
			end
			
			expect(result).to be == :block_result
			expect(promise.resolved?).to be == true
			expect(promise.wait).to be == :block_result
		end
		
		it "rejects when the block raises an exception" do
			test_error = StandardError.new("block error")
			
			expect do
				promise.fulfill do
					raise test_error
				end
			end.to raise_exception(StandardError, message: be =~ /block error/)
			
			expect(promise.resolved?).to be == true
			expect(promise.value).to be == test_error
			
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /block error/)
		end
		
		it "raises if promise is already resolved" do
			promise.resolve(:already_done)
			
			expect do
				promise.fulfill do
					:ignored
				end
			end.to raise_exception(RuntimeError, message: be =~ /already resolved/)
		end
		
		it "raises if promise is already rejected" do
			promise.reject(StandardError.new("already failed"))
			
			expect do
				promise.fulfill do
					:ignored
				end
			end.to raise_exception(RuntimeError, message: be =~ /already resolved/)
		end
		
		it "handles block that returns nil" do
			result = promise.fulfill do
				nil
			end
			
			expect(result).to be_nil
			expect(promise.wait).to be_nil
		end
		
		it "handles block with complex exception handling" do
			# Test the ensure block behavior when an exception occurs:
			promise = Async::Promise.new
			
			expect do
				promise.fulfill do
					raise StandardError.new("complex error")
				end
			end.to raise_exception(StandardError, message: be =~ /complex error/)
			
			# Promise should be rejected, not resolved with nil:
			expect(promise.resolved?).to be == true
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /complex error/)
		end
	end
	
	with "concurrency" do
		it "handles concurrent resolve and reject" do
			results = []
			
			# Start concurrent resolution attempts:
			tasks = [
				reactor.async { promise.resolve(:first) },
				reactor.async { promise.reject(StandardError.new("second")) },
				reactor.async { promise.resolve(:third) }
			]
			
			tasks.each(&:wait)
			
			# One of them should have won, promise should be resolved:
			expect(promise.resolved?).to be == true
			
			# The result should be deterministic (first one wins):
			expect(promise.value).to be == :first
			expect(promise.wait).to be == :first
		end
		
		it "handles waiting and resolution race conditions" do
			results = []
			
			# Start waiter and resolver concurrently:
			waiter = reactor.async do
				results << promise.wait
			end
			
			resolver = reactor.async do
				promise.resolve(:race_result)
			end
			
			[waiter, resolver].each(&:wait)
			
			expect(results).to be == [:race_result]
		end
	end
end
