
RSpec.shared_examples 'chainable async' do
	let(:parent) {double}
	subject {described_class.new(parent: parent)}
	
	it 'should chain async to parent' do
		expect(parent).to receive(:async)
		
		subject.async do
		end
	end
end
