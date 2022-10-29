# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2019-2022, by Samuel Williams.

ChainableAsync = Sus::Shared("chainable async") do
	let(:parent) {Object.new}
	
	it 'should chain async to parent' do
		instance = subject.new(parent: parent)
		
		expect(parent).to receive(:async).and_return(nil)
		
		instance.async do
		end
	end
end
