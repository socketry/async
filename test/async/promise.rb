# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

require "async/promise"

require "sus/fixtures/async"

describe Async::Promise do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:promise) {subject.new}
	
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
			expect(errors).to be(:all?) {|error| error == test_error}
			expect(promise.waiting?).to be == false
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
	
	with "#cancel" do
		it "can be cancelled" do
			promise.cancel
			
			expect(promise.resolved?).to be == true
			expect(promise.cancelled?).to be == true
			expect(promise.completed?).to be == false
			expect(promise.failed?).to be == false
			expect(promise.value).to be_a(Async::Promise::Cancel)
			
			expect do
				promise.wait
			end.to raise_exception(Async::Promise::Cancel, message: be =~ /cancelled/)
		end
		
		it "can be cancelled with custom exception" do
			custom_error = StandardError.new("custom cancellation")
			promise.cancel(custom_error)
			
			expect(promise.cancelled?).to be == true
			expect(promise.value).to be == custom_error
			
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /custom cancellation/)
		end
		
		it "ignores subsequent cancel calls" do
			promise.cancel(StandardError.new("first cancel"))
			promise.cancel(StandardError.new("second cancel"))
			
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /first cancel/)
		end
		
		it "ignores resolve after cancel" do
			promise.cancel
			promise.resolve(:ignored)
			
			expect(promise.cancelled?).to be == true
			expect do
				promise.wait
			end.to raise_exception(Async::Promise::Cancel)
		end
		
		it "ignores reject after cancel" do
			promise.cancel
			promise.reject(StandardError.new("ignored"))
			
			expect(promise.cancelled?).to be == true
			expect do
				promise.wait
			end.to raise_exception(Async::Promise::Cancel)
		end
		
		it "handles multiple concurrent waiters with cancellation" do
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
			
			# Cancel - all waiters should get the cancel exception:
			promise.cancel(StandardError.new("shared cancellation"))
			waiters.each(&:wait)
			
			expect(results).to be(:empty?)
			expect(errors.size).to be == 3
			expect(errors).to be(:all?) {|error| error.message =~ /shared cancellation/}
			expect(promise.waiting?).to be == false
		end
	end
	
	with "state predicates" do
		it "reports correct state for completed promise" do
			promise.resolve(:success)
			
			expect(promise.resolved?).to be == true
			expect(promise.completed?).to be == true
			expect(promise.failed?).to be == false
			expect(promise.cancelled?).to be == false
		end
		
		it "reports correct state for failed promise" do
			promise.reject(StandardError.new("error"))
			
			expect(promise.resolved?).to be == true
			expect(promise.completed?).to be == false
			expect(promise.failed?).to be == true
			expect(promise.cancelled?).to be == false
		end
		
		it "reports correct state for cancelled promise" do
			promise.cancel
			
			expect(promise.resolved?).to be == true
			expect(promise.completed?).to be == false
			expect(promise.failed?).to be == false
			expect(promise.cancelled?).to be == true
		end
		
		it "reports correct state for pending promise" do
			expect(promise.resolved?).to be == false
			expect(promise.completed?).to be == false
			expect(promise.failed?).to be == false
			expect(promise.cancelled?).to be == false
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
			
			# StandardError is absorbed by fulfill (not re-raised to caller):
			result = promise.fulfill do
				raise test_error
			end
			
			expect(result).to be_nil
			expect(promise.resolved?).to be == true
			expect(promise.failed?).to be == true
			expect(promise.value).to be == test_error
			
			# But promise.wait still raises the exception:
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
			
			# StandardError is absorbed by fulfill (not re-raised):
			result = promise.fulfill do
				raise StandardError.new("complex error")
			end
			
			expect(result).to be_nil
			# Promise should be rejected, not resolved with nil:
			expect(promise.resolved?).to be == true
			expect(promise.failed?).to be == true
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /complex error/)
		end
		
		it "handles Cancel exceptions (absorbed, not re-raised)" do
			cancel_exception = Async::Promise::Cancel.new("user cancelled")
			
			result = promise.fulfill do
				raise cancel_exception
			end
			
			# Cancel exceptions are absorbed - no re-raise to caller:
			expect(result).to be_nil
			expect(promise.cancelled?).to be == true
			expect(promise.value).to be == cancel_exception
			
			# But promise.wait will raise the cancel exception:
			expect do
				promise.wait
			end.to raise_exception(Async::Promise::Cancel, message: be =~ /user cancelled/)
		end
		
		it "handles custom Cancel exceptions" do
			custom_cancel = StandardError.new("custom stop")
			
			result = promise.fulfill do
				raise Async::Promise::Cancel.new("wrapper").tap{|c| c.instance_variable_set(:@cause, custom_cancel)}
			end
			
			expect(result).to be_nil
			expect(promise.cancelled?).to be == true
		end
		
		it "handles StandardError exceptions (absorbed, not re-raised)" do
			test_error = StandardError.new("business logic error")
			
			result = promise.fulfill do
				raise test_error
			end
			
			# StandardError exceptions are absorbed - no re-raise to caller:
			expect(result).to be_nil
			expect(promise.failed?).to be == true
			expect(promise.value).to be == test_error
			
			# But promise.wait will raise the exception:
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /business logic error/)
		end
		
		it "handles system exceptions (propagated to caller)" do
			system_error = NoMemoryError.new("critical system error")
			
			expect do
				promise.fulfill do
					raise system_error
				end
			end.to raise_exception(NoMemoryError, message: be =~ /critical system error/)
			
			# Promise should still be failed:
			expect(promise.failed?).to be == true
			expect(promise.value).to be == system_error
		end
		
		it "handles non-local exit with 'next'" do
			result = promise.fulfill do
				next :early_exit
			end
			
			# 'next' should work normally - block returns value:
			expect(result).to be == :early_exit
			expect(promise.completed?).to be == true
			expect(promise.wait).to be == :early_exit
		end
		
		it "handles non-local exit with 'throw'" do
			result = catch(:tag) do
				promise.fulfill do
					throw :tag, :thrown_value
				end
			end
			
			# throw bypasses normal return but ensure block should resolve promise:
			expect(result).to be == :thrown_value
			expect(promise.resolved?).to be == true
			expect(promise.completed?).to be == true
			expect(promise.wait).to be_nil  # ensure block resolves with nil
		end
		
		it "ensure block handles all non-exception exits" do
			# Test that ensure block properly resolves promise for any exit mechanism
			promise1 = Async::Promise.new
			
			# Block that would leave promise unresolved without ensure:
			catch(:exit) do
				promise1.fulfill do
					throw :exit
				end
			end
			
			# Promise should be resolved by ensure block:
			expect(promise1.resolved?).to be == true
			expect(promise1.completed?).to be == true
		end
		
		it "ensure block doesn't interfere with normal exception handling" do
			# Make sure ensure doesn't override proper exception handling
			test_error = StandardError.new("should be handled normally")
			
			result = promise.fulfill do
				raise test_error
			end
			
			# Should be handled by rescue, not ensure:
			expect(result).to be_nil
			expect(promise.failed?).to be == true
			expect(promise.value).to be == test_error
		end
		
		it "exception hierarchy is handled in correct order" do
			# Test that more specific exceptions are caught before general ones
			promise1 = Async::Promise.new
			promise2 = Async::Promise.new
			promise3 = Async::Promise.new
			
			# Cancel exception should be caught specifically:
			promise1.fulfill{raise Async::Promise::Cancel.new}
			expect(promise1.cancelled?).to be == true
			
			# StandardError should be caught by rescue =>:
			promise2.fulfill{raise ArgumentError.new("standard")}
			expect(promise2.failed?).to be == true
			
			# System exception should be caught by rescue Exception and re-raised:
			expect do
				promise3.fulfill{raise SystemExit.new}
			end.to raise_exception(SystemExit)
			expect(promise3.failed?).to be == true
		end
	end
	
	with "concurrency" do
		it "handles concurrent resolve and reject" do
			results = []
			
			# Start concurrent resolution attempts:
			tasks = [
				reactor.async{promise.resolve(:first)},
				reactor.async{promise.reject(StandardError.new("second"))},
				reactor.async{promise.resolve(:third)}
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
	
	with "immutability edge cases" do
		it "cancel after resolve is ignored" do
			promise.resolve(:success)
			original_value = promise.value
			
			promise.cancel(StandardError.new("should be ignored"))
			
			expect(promise.completed?).to be == true
			expect(promise.value).to be == original_value
			expect(promise.wait).to be == :success
		end
		
		it "cancel after reject is ignored" do
			error = StandardError.new("original error")
			promise.reject(error)
			original_value = promise.value
			
			promise.cancel(StandardError.new("should be ignored"))
			
			expect(promise.failed?).to be == true
			expect(promise.value).to be == original_value
			expect do
				promise.wait
			end.to raise_exception(StandardError, message: be =~ /original error/)
		end
		
		it "resolve after cancel is ignored" do
			promise.cancel
			original_value = promise.value
			
			promise.resolve(:should_be_ignored)
			
			expect(promise.cancelled?).to be == true
			expect(promise.value).to be == original_value
			expect do
				promise.wait
			end.to raise_exception(Async::Promise::Cancel)
		end
		
		it "reject after cancel is ignored" do
			promise.cancel
			original_value = promise.value
			
			promise.reject(StandardError.new("should be ignored"))
			
			expect(promise.cancelled?).to be == true
			expect(promise.value).to be == original_value
			expect do
				promise.wait
			end.to raise_exception(Async::Promise::Cancel)
		end
		
		it "fulfill after cancel raises already resolved error" do
			promise.cancel
			
			expect do
				promise.fulfill{:should_not_execute}
			end.to raise_exception(RuntimeError, message: be =~ /already resolved/)
		end
		
		it "multiple resolution attempts are deterministic" do
			# First resolution wins, regardless of type
			promise.resolve(:first)
			promise.reject(StandardError.new("second"))
			promise.cancel(StandardError.new("third"))
			promise.resolve(:fourth)
			
			expect(promise.completed?).to be == true
			expect(promise.wait).to be == :first
		end
	end
	
	with ".fulfill" do
		it "fulfills the promise when given" do
			promise = Async::Promise.new
			
			result = Async::Promise.fulfill(promise) do
				:block_result
			end
			
			expect(result).to be == :block_result
			expect(promise.resolved?).to be == true
			expect(promise.wait).to be == :block_result
		end
		
		it "simply yields when no promise is given" do
			result = Async::Promise.fulfill(nil) do
				:direct_result
			end
			
			expect(result).to be == :direct_result
		end
		
		it "handles exceptions when promise is given" do
			promise = Async::Promise.new
			test_error = StandardError.new("test error")
			
			result = Async::Promise.fulfill(promise) do
				raise test_error
			end
			
			expect(result).to be_nil
			expect(promise.failed?).to be == true
			expect(promise.value).to be == test_error
		end
		
		it "propagates exceptions when no promise is given" do
			test_error = StandardError.new("test error")
			
			expect do
				Async::Promise.fulfill(nil) do
					raise test_error
				end
			end.to raise_exception(StandardError, message: be =~ /test error/)
		end
		
		it "works with falsy promise values" do
			# Test that it properly checks for nil/false, not just truthiness
			result = Async::Promise.fulfill(false) do
				:should_yield_directly
			end
			
			expect(result).to be == :should_yield_directly
		end
	end
end

describe Async::Promise do
	include Sus::Fixtures::Async::ReactorContext
	
	let(:promise) {subject.new}
	
	describe "#wait" do
		it "handles spurious wake-ups gracefully" do
			promise = Async::Promise.new
			result = nil
			
			thread = Thread.new do
				result = promise.wait
			rescue => error
				# Pass.
			end
			
			Thread.pass until thread.stop?
			
			10.times do
				thread.wakeup # Trigger spurious wake-up.
				Thread.pass
			end
			
			promise.resolve(:success)
			thread.join
			
			expect(result).to be == :success
		end
	end
end
