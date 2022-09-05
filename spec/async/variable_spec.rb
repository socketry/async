# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2021-2022, by Samuel Williams.

require 'async/variable'

RSpec.shared_examples_for Async::Variable do |value|
	it "can resolve the value to #{value.inspect}" do
		subject.resolve(value)
		is_expected.to be_resolved
	end
	
	it "can wait for the value to be resolved" do
		Async do
			expect(subject.wait).to be value
		end
		
		subject.resolve(value)
	end
	
	it "can't resolve it a 2nd time" do
		subject.resolve(value)
		expect do
			subject.resolve(value)
		end.to raise_exception(FrozenError)
	end
end

RSpec.describe Async::Variable do
	include_context Async::RSpec::Reactor
	
	it_behaves_like Async::Variable, true
	it_behaves_like Async::Variable, false
	it_behaves_like Async::Variable, nil
	it_behaves_like Async::Variable, Object.new
end
