# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Patrik Wenger.

require "sus/fixtures/async"
require "async/promise"

PromiseContext = Sus::Shared("a promise") do
	let(:promise) {Async::Promise.new}
	
	it "can resolve the value" do
		promise.resolve(value)
		expect(promise).to be(:resolved?)
	end
	
	it "can wait for the value to be resolved" do
		Async do
			expect(promise.wait).to be == value
		end
		
		promise.resolve(value)
	end

	it "can wait for the value to be resolved using setter" do
		Async do
			expect(promise.wait).to be == value
		end
		
		promise.value = value
	end
	
	it "can't resolve it a 2nd time" do
		promise.resolve(value)
		expect do
			promise.resolve(value)
		end.to raise_exception(FrozenError)
	end

	it "can reject with an exception" do
		promise.reject RuntimeError.new("boom")
		expect(promise).to be(:resolved?)
		expect(promise).to be(:rejected?)
	end

	it "can wait for a rejection with an error" do
		Async do
			expect do
				promise.wait
			end.to raise_exception(RuntimeError)
		end
		
		promise.reject(RuntimeError.new)
	end
end

include Sus::Fixtures::Async::ReactorContext

describe true do
	let(:value) {subject}
	it_behaves_like PromiseContext
end

describe false do
	let(:value) {subject}
	it_behaves_like PromiseContext
end

describe nil do
	let(:value) {subject}
	it_behaves_like PromiseContext
end

describe Object do
	let(:value) {subject.new}
	it_behaves_like PromiseContext
end
