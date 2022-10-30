# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.
# Copyright, 2022, by Shannon Skipper.

require 'async/node'

describe Async::Node do
	let(:node) {subject.new}
	
	with '#children?' do
		with "no children" do
			it "hasn't got any children" do
				expect(node).not.to be(:children?)
			end
		end
		
		with "one child" do
			it "has children" do
				child = Async::Node.new(node)
				expect(node).to be(:children?)
			end
		end
	end
	
	with '#parent=' do
		let(:child) {Async::Node.new(node)}
		
		it "should construct nested tree" do
			expect(child.parent).to be == node
			expect(node.children).to be(:include?, child)
		end
		
		it "should break nested tree" do
			child.parent = nil
			
			expect(child.parent).to be_nil
			expect(node.children).to be_nil
		end
		
		it "can consume bottom to top" do
			child.consume
			
			expect(child.parent).to be_nil
			expect(node.children).to be_nil
		end
		
		it "can move a child from one parent to another" do
			another_parent = Async::Node.new
			child.parent = another_parent
			
			expect(node.children).to be(:empty?)
			expect(child.parent).to be == another_parent
		end
	end
	
	with '#print_hierarchy' do
		let(:buffer) {StringIO.new}
		let(:output) {buffer.string}
		let(:lines) {output.lines}
		
		it "can print hierarchy to bufffer" do
			child = Async::Node.new(node)
			
			node.print_hierarchy(buffer)
			
			expect(lines.size).to be == 2
			
			expect(lines[0]).to be =~ /#<Async::Node:0x\h+>\n/
			expect(lines[1]).to be =~ /\t#<Async::Node:0x\h+>\n/
		end
	end

with '#inspect' do
	let(:node) {Async::Node.new}
		
		it 'should begin with the class name' do
			expect(node.inspect).to be(:start_with?, "#<#{node.class.name}")
		end
		
		it 'should end with hex digits' do
			expect(node.inspect).to be =~ /\h>\z/
		end
		
		it 'should have a standard number of hex digits' do
			expect(node.inspect).to be =~ /:0x\h{16}>/
		end
		
		it 'should have a colon in the middle' do
			name, middle, hex = node.inspect.rpartition(':')
			
			expect(name).to be(:end_with?, node.class.name)
			expect(middle).to be == ':'
			expect(hex).to be =~ /\A\h+/
		end
	end
	
	with '#consume' do
		it "can't consume middle node" do
			middle = Async::Node.new(node)
			bottom = Async::Node.new(middle)
			
			expect(bottom.parent).to be_equal(middle)
			
			middle.consume
			
			expect(bottom.parent).to be_equal(middle)
		end
		
		it "can consume nodes while enumerating children" do
			3.times do
				Async::Node.new(node)
			end
			
			children = node.children.each.to_a
			expect(children.size).to be == 3
			
			enumerated = []
			
			node.children.each do |child|
				child.consume
				enumerated << child
			end
			
			expect(enumerated).to be == children
		end
		
		it "can consume multiple nodes while enumerating children" do
			3.times do
				Async::Node.new(node)
			end
			
			children = node.children.each.to_a
			expect(children.size).to be == 3
			
			enumerated = []
			
			node.children.each do |child|
				# On the first iteration, we consume the first two children:
				children[0].consume
				children[1].consume
				
				# This would end up appending the first child, and then the third child:
				enumerated << child
			end
			
			expect(enumerated).to be == [children[0], children[2]]
		end
		
		it "correctly enumerates finished children" do
			middle = Async::Node.new(node)
			bottom = 2.times.map{Async::Node.new(middle)}
			
			expect(bottom[0]).to receive(:finished?).and_return(false)
			expect(bottom[1]).to receive(:finished?).and_return(false)
			expect(middle).to receive(:finished?).and_return(true)
			
			middle.consume
			
			expect(node.children.size).to be == 2
			expect(node.children.each.to_a).to be == bottom
		end
		
		it "deletes children that are also finished" do
			middle = Async::Node.new(node)
			bottom = Async::Node.new(middle)
			
			expect(middle).to receive(:finished?).and_return(true)
			expect(bottom).to receive(:finished?).and_return(true)
			
			middle.consume
			
			expect(node.children).to be(:empty?)
			expect(middle.children).to be_nil
			expect(bottom.parent).to be_nil
		end
	end
	
	with '#annotate' do
		let(:annotation) {'reticulating splines'}
		
		it "should have no annotation by default" do
			expect(node.annotation).to be_nil
		end
		
		it 'should output annotation when invoking #to_s' do
			node.annotate(annotation) do
				expect(node.to_s).to be(:include?, annotation)
			end
		end
		
		it 'can assign annotation' do
			node.annotate(annotation)
			
			expect(node.annotation).to be == annotation
		end
	end
	
	with '#transient' do
		it 'can move transient child to parent' do
			# This example represents a persistent web connection (middle) with a background reader (child). We look at how when that connection goes out of scope, what happens to the child.
			
			# node -> middle -> child (transient)
			
			middle = Async::Node.new(node)
			child = Async::Node.new(middle, transient: true)
			
			expect(child).to be(:transient?)
			expect(middle).to be(:finished?)
			
			expect(child).to receive(:finished?).with_call_count(be >= 1).and_return(false)
			
			middle.consume
			
			# node -> child (transient)
			expect(child.parent).to be_equal(node)
			expect(node.children).to be(:include?, child)
			expect(node.children).not.to be(:include?, middle)
			
			expect(child).not.to be(:finished?)
			expect(node).to be(:finished?)
			
			expect(child).to receive(:stop)
			node.terminate
		end
		
		it 'can move transient sibling to parent' do
			# This example represents a server task (middle) which has a single task listening on incoming connections (child2), and a transient task which is monitoring those connections/some shared resource (child1). We look at what happens when the server listener finishes.
			
			# node -> middle -> child1 (transient)
			#                   -> child2
			middle = Async::Node.new(node, annotation: "middle")
			child1 = Async::Node.new(middle, transient: true, annotation: "child1")
			child2 = Async::Node.new(middle, annotation: "child2")
			
			expect(child1).to receive(:finished?).and_return(false)
			
			middle.consume
			
			# node -> middle -> child1 (transient)
			#                   -> child2
			expect(child1.parent).to be_equal(middle)
			expect(child2.parent).to be_equal(middle)
			expect(middle.parent).to be_equal(node)
			expect(node.children).to be(:include?, middle)
			expect(middle.children).to be(:include?, child1)
			expect(middle.children).to be(:include?, child2)
			
			child2.consume
			
			# node -> child1 (transient)
			expect(child1.parent).to be_equal(node)
			expect(child2.parent).to be_nil
			expect(middle.parent).to be_nil
			expect(node.children).to be(:include?, child1)
			expect(middle.children).to be_nil
		end
		
		it 'ignores non-transient children of transient parent' do
			# node -> middle (transient) -> child
			middle = Async::Node.new(node, transient: true)
			child = Async::Node.new(middle)
			
			expect(middle).to receive(:finished?).and_return(false)
			
			child.consume
			
			# node -> middle (transient)
			expect(child.parent).to be_nil
			expect(middle.parent).to be_equal(node)
			expect(node.children).to be(:include?, middle)
			expect(middle.children).to be_nil
		end
		
		it 'does not stop child transient tasks' do
			middle = Async::Node.new(node, annotation: "middle")
			child1 = Async::Node.new(middle, transient: true, annotation: "child1")
			child2 = Async::Node.new(middle, annotation: "child2")
			
			expect(child1).not.to receive(:stop)
			expect(child2).to receive(:stop)
			
			node.stop
		end
	end
	
	with '#terminate' do
		it 'stops all tasks' do
			middle = Async::Node.new(node, annotation: "middle")
			child1 = Async::Node.new(middle, transient: true, annotation: "child1")
			child2 = Async::Node.new(middle, annotation: "child2")
			
			expect(child1).to receive(:stop)
			expect(child2).to receive(:stop).with_call_count(be >= 1)
			
			node.terminate
		end
	end
end
