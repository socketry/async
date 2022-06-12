# frozen_string_literal: true

# Copyright, 2017, by Samuel G. D. Williams. <http://www.codeotaku.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'async/node'

RSpec.describe Async::Children do
	context "with no children" do
		describe '#nil?' do
			it {is_expected.to be_nil}
		end
		
		describe '#empty?' do
			it {is_expected.to be_empty}
		end
		
		describe '#transients?' do
			it {is_expected.to_not be_transients}
		end
	end
end

RSpec.describe Async::Node do	
	describe '#children?' do
		context "with no children" do
			it {is_expected.to_not be_children}
		end
	end
	
	describe '#parent=' do
		let(:child) {Async::Node.new(subject)}
		
		it "should construct nested tree" do
			expect(child.parent).to be subject
			expect(subject.children).to include(child)
		end
		
		it "should break nested tree" do
			child.parent = nil
			
			expect(child.parent).to be_nil
			expect(subject.children).to be_nil
		end
		
		it "can consume bottom to top" do
			child.consume
			
			expect(child.parent).to be_nil
			expect(subject.children).to be_nil
		end
		
		it "can move a child from one parent to another" do
			another_parent = Async::Node.new
			child.parent = another_parent
			
			expect(subject.children).to be_empty
			expect(child.parent).to be == another_parent
		end
	end
	
	describe '#print_hierarchy' do
		let(:buffer) {StringIO.new}
		let(:output) {buffer.string}
		let(:lines) {output.lines}
		
		let!(:child) {Async::Node.new(subject)}
		
		it "can print hierarchy to bufffer" do
			subject.print_hierarchy(buffer)
			
			expect(lines.size).to be 2
			
			expect(lines[0]).to be =~ /#<Async::Node:0x\h+>\n/
			expect(lines[1]).to be =~ /\t#<Async::Node:0x\h+>\n/
		end
	end

	describe '#inspect' do
		let(:node) {Async::Node.new}
		
		it 'should begin with the class name' do
			expect(node.inspect).to start_with "#<#{node.class.name}"
		end
		
		it 'should end with hex digits' do
			expect(node.inspect).to match(/\h>\z/)
		end
		
		it 'should have a standard number of hex digits' do
			expect(node.inspect).to match(/:0x\h{16}>/)
		end
		
		it 'should have a colon in the middle' do
			name, middle, hex = node.inspect.rpartition(':')
			
			expect(name).to end_with node.class.name
			expect(middle).to eq ':'
			expect(hex).to match(/\A\h+/)
		end
	end
	
	describe '#consume' do
		it "can't consume middle node" do
			middle = Async::Node.new(subject)
			bottom = Async::Node.new(middle)
			
			expect(bottom.parent).to be middle
			
			middle.consume
			
			expect(bottom.parent).to be middle
		end
		
		it "can consume nodes while enumerating children" do
			3.times do
				Async::Node.new(subject)
			end
			
			children = subject.children.each.to_a
			expect(children.size).to be == 3
			
			enumerated = []
			
			subject.children.each do |child|
				child.consume
				enumerated << child
			end
			
			expect(enumerated).to be == children
		end
		
		it "can consume multiple nodes while enumerating children" do
			3.times do
				Async::Node.new(subject)
			end
			
			children = subject.children.each.to_a
			expect(children.size).to be == 3
			
			enumerated = []
			
			subject.children.each do |child|
				# On the first iteration, we consume the first two children:
				children[0].consume
				children[1].consume
				
				# This would end up appending the first child, and then the third child:
				enumerated << child
			end
			
			expect(enumerated).to be == [children[0], children[2]]
		end
		
		it "correctly enumerates finished children" do
			middle = Async::Node.new(subject)
			bottom = 2.times.map{Async::Node.new(middle)}
			
			allow(bottom[0]).to receive(:finished?).and_return(false)
			allow(bottom[1]).to receive(:finished?).and_return(false)
			
			allow(middle).to receive(:finished?).and_return(true)
			middle.consume
			
			expect(subject.children.size).to be == 2
			expect(subject.children.each.to_a).to be == bottom
		end
		
		it "deletes children that are also finished" do
			middle = Async::Node.new(subject)
			bottom = Async::Node.new(middle)
			
			allow(middle).to receive(:finished?).and_return(true)
			allow(bottom).to receive(:finished?).and_return(true)
			
			middle.consume
			
			expect(subject.children).to be_empty
			expect(middle.children).to be_nil
			expect(bottom.parent).to be_nil
		end
	end
	
	describe '#annotate' do
		let(:annotation) {'reticulating splines'}
		
		it "should have no annotation by default" do
			expect(subject.annotation).to be_nil
		end
		
		it 'should output annotation when invoking #to_s' do
			subject.annotate(annotation) do
				expect(subject.to_s).to include(annotation)
			end
		end
		
		it 'can assign annotation' do
			subject.annotate(annotation)
			
			expect(subject.annotation).to be == annotation
		end
	end
	
	describe '#transient' do
		it 'can move transient child to parent' do
			# This example represents a persistent web connection (middle) with a background reader (child). We look at how when that connection goes out of scope, what happens to the child.
			
			# subject -> middle -> child (transient)
			
			middle = Async::Node.new(subject)
			child = Async::Node.new(middle, transient: true)
			
			expect(child).to be_transient
			expect(middle).to be_finished
			
			allow(child).to receive(:finished?).and_return(false)
			
			middle.consume
			
			# subject -> child (transient)
			expect(child.parent).to be subject
			expect(subject.children).to include(child)
			expect(subject.children).to_not include(middle)
			
			expect(child).to_not be_finished
			expect(subject).to be_finished
			
			expect(child).to receive(:stop)
			subject.terminate
		end
		
		it 'can move transient sibling to parent' do
			# This example represents a server task (middle) which has a single task listening on incoming connections (child2), and a transient task which is monitoring those connections/some shared resource (child1). We look at what happens when the server listener finishes.
			
			# subject -> middle -> child1 (transient)
			#                   -> child2
			middle = Async::Node.new(subject, annotation: "middle")
			child1 = Async::Node.new(middle, transient: true, annotation: "child1")
			child2 = Async::Node.new(middle, annotation: "child2")
			
			allow(child1).to receive(:finished?).and_return(false)
			
			middle.consume
			
			# subject -> middle -> child1 (transient)
			#                   -> child2
			expect(child1.parent).to be middle
			expect(child2.parent).to be middle
			expect(middle.parent).to be subject
			expect(subject.children).to include(middle)
			expect(middle.children).to include(child1)
			expect(middle.children).to include(child2)
			
			child2.consume
			
			# subject -> child1 (transient)
			expect(child1.parent).to be subject
			expect(child2.parent).to be_nil
			expect(middle.parent).to be_nil
			expect(subject.children).to include(child1)
			expect(middle.children).to be_nil
		end
		
		it 'ignores non-transient children of transient parent' do
			# subject -> middle (transient) -> child
			middle = Async::Node.new(subject, transient: true)
			child = Async::Node.new(middle)
			
			allow(middle).to receive(:finished?).and_return(false)
			
			child.consume
			
			# subject -> middle (transient)
			expect(child.parent).to be_nil
			expect(middle.parent).to be subject
			expect(subject.children).to include(middle)
			expect(middle.children).to be_nil
		end
		
		it 'does not stop child transient tasks' do
			middle = Async::Node.new(subject, annotation: "middle")
			child1 = Async::Node.new(middle, transient: true, annotation: "child1")
			child2 = Async::Node.new(middle, annotation: "child2")
			
			expect(child1).to_not receive(:stop)
			expect(child2).to receive(:stop)
			
			subject.stop
		end
	end
	
	describe '#terminate' do
		it 'stops all tasks' do
			middle = Async::Node.new(subject, annotation: "middle")
			child1 = Async::Node.new(middle, transient: true, annotation: "child1")
			child2 = Async::Node.new(middle, annotation: "child2")
			
			expect(child1).to receive(:stop).at_least(:once)
			expect(child2).to receive(:stop).at_least(:once)
			
			subject.terminate
		end
	end
end
