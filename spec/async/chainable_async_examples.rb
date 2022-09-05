# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

RSpec.shared_examples 'chainable async' do
	let(:parent) {double}
	subject {described_class.new(parent: parent)}
	
	it 'should chain async to parent' do
		expect(parent).to receive(:async)
		
		subject.async do
		end
	end
end
