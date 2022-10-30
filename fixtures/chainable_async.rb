# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

ChainableAsync = Sus::Shared("chainable async") do
	let(:parent) {Object.new}
	let(:chainable) {subject.new(parent: parent)}
	
	it 'should chain async to parent' do
		expect(parent).to receive(:async).and_return(nil)
		
		chainable.async do
			# Nothing.
		end
	end
end
