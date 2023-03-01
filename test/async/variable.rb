# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

require 'sus/fixtures/async'
require 'async/variable'

VariableContext = Sus::Shared("a variable") do
	let(:variable) {Async::Variable.new}
	
	it "can resolve the value" do
		variable.resolve(value)
		expect(variable).to be(:resolved?)
	end
	
	it "can wait for the value to be resolved" do
		Async do
			expect(variable.wait).to be == value
		end
		
		variable.resolve(value)
	end
	
	it "can't resolve it a 2nd time" do
		variable.resolve(value)
		expect do
			variable.resolve(value)
		end.to raise_exception(FrozenError)
	end
end

include Sus::Fixtures::Async::ReactorContext

describe true do
	let(:value) {subject}
	it_behaves_like VariableContext
end

describe false do
	let(:value) {subject}
	it_behaves_like VariableContext
end

describe nil do
	let(:value) {subject}
	it_behaves_like VariableContext
end

describe Object do
	let(:value) {subject.new}
	it_behaves_like VariableContext
end
