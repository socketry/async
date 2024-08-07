# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2024, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.

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
	
	with "transient children" do
		let(:parent) {Async::Node.new}
		let(:children) {parent.children}
		
		it "can add a transient child" do
			child = Async::Node.new(parent, transient: true)
			expect(children).to be(:transients?)
			
			child.transient = false
			expect(children).not.to be(:transients?)
			expect(parent).not.to be(:finished?)
			
			child.transient = true
			expect(children).to be(:transients?)
			expect(parent).to be(:finished?)
		end
	end
end
