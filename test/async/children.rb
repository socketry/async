# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022-2023, by Samuel Williams.

require 'async/node'

describe Async::Children do
	let(:children) {subject.new}
	
	with "no children" do
		it "should be empty" do
			expect(children).to be(:empty?)
			expect(children).to be(:nil?)
			expect(children).not.to be(:transients?)
		end
	end
	
	with "one child" do
		it "can add a child" do
			child = Async::Node.new
			children.append(child)
			
			expect(children).not.to be(:empty?)
		end
		
		it "can't remove a child that hasn't been inserted" do
			child = Async::Node.new
			
			expect{children.remove(child)}.to raise_exception(ArgumentError, message: be =~ /not in a list/)
		end
		
		it "can't remove the child twice" do
			child = Async::Node.new
			children.append(child)
			
			children.remove(child)
			
			expect{children.remove(child)}.to raise_exception(ArgumentError, message: be =~ /not in a list/)
		end
	end
end
