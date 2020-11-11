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

module Async
	# A double linked list.
	class List
		def initialize
			@head = nil
			@tail = nil
			@size = 0
		end
		
		attr :size
		
		attr_accessor :head
		attr_accessor :tail
		
		# Inserts an item at the end of the list.
		def insert(item)
			unless @head
				@head = item
				@tail = item
				
				# Consistency:
				item.head = nil
				item.tail = nil
			else
				@tail.tail = item
				item.head = @tail
				
				# Consistency:
				item.tail = nil
				
				@tail = item
			end
			
			@size += 1
			
			return self
		end
		
		def delete(item)
			if @head.equal?(item)
				@head = @head.tail
			else
				item.head.tail = item.tail
			end
			
			if @tail.equal?(item)
				@tail = @tail.head
			else
				item.tail.head = item.head
			end
			
			item.head = nil
			item.tail = nil
			
			@size -= 1
			
			return self
		end
		
		def each
			return to_enum unless block_given?
			
			item = @head
			while item
				# We store the tail pointer so we can remove the current item from the linked list:
				tail = item.tail
				yield item
				item = tail
			end
		end
		
		def include?(needle)
			self.each do |item|
				return true if needle.equal?(item)
			end
			
			return false
		end
		
		def first
			@head
		end
		
		def last
			@tail
		end
		
		def empty?
			@head.nil?
		end
		
		def nil?
			@head.nil?
		end
	end
	
	private_constant :List
	
	class Children < List
		def initialize
			super
			
			@transient_count = 0
		end
		
		# Does this node have (direct) transient children?
		def transients?
			@transient_count > 0
		end
		
		def insert(item)
			if item.transient?
				@transient_count += 1
			end
			
			super
		end
		
		def delete(item)
			if item.transient?
				@transient_count -= 1
			end
			
			super
		end
		
		def finished?
			@size == @transient_count
		end
	end
	
	# Represents a node in a tree, used for nested {Task} instances.
	class Node
		# Create a new node in the tree.
		# @param parent [Node, nil] This node will attach to the given parent.
		def initialize(parent = nil, annotation: nil, transient: false)
			@parent = nil
			@children = nil
			
			@annotation = annotation
			@object_name = nil
			
			@transient = transient
			
			@head = nil
			@tail = nil
			
			if parent
				parent.add_child(self)
			end
		end
		
		# You should not directly rely on these pointers but instead use `#children`.
		# List pointers:
		attr_accessor :head
		attr_accessor :tail
		
		# @attr parent [Node, nil]
		attr :parent
		
		# @attr children [List<Node>] Optional list of children.
		attr :children
		
		# A useful identifier for the current node.
		attr :annotation
		
		# Whether there are children?
		def children?
			@children != nil && !@children.empty?
		end
		
		# Is this node transient?
		def transient?
			@transient
		end
		
		def annotate(annotation)
			if block_given?
				previous_annotation = @annotation
				@annotation = annotation
				yield
				@annotation = previous_annotation
			else
				@annotation = annotation
			end
		end
		
		def description
			@object_name ||= "#{self.class}:0x#{object_id.to_s(16)}#{@transient ? ' transient' : nil}"
			
			if @annotation
				"#{@object_name} #{@annotation}"
			else
				@object_name
			end
		end
		
		def backtrace(*arguments)
			nil
		end
		
		def to_s
			"\#<#{description}>"
		end
		
		# Change the parent of this node.
		# @param parent [Node, nil] the parent to attach to, or nil to detach.
		# @return [self]
		def parent=(parent)
			return if @parent.equal?(parent)
			
			if @parent
				@parent.delete_child(self)
				@parent = nil
			end
			
			if parent
				parent.add_child(self)
			end
			
			return self
		end
		
		protected def set_parent parent
			@parent = parent
		end
		
		protected def add_child child
			@children ||= Children.new
			@children.insert(child)
			child.set_parent(self)
		end
		
		protected def delete_child(child)
			@children.delete(child)
			child.set_parent(nil)
		end
		
		# Whether the node can be consumed safely. By default, checks if the
		# children set is empty.
		# @return [Boolean]
		def finished?
			@children.nil? || @children.finished?
		end
		
		# If the node has a parent, and is {finished?}, then remove this node from
		# the parent.
		def consume
			if parent = @parent and finished?
				parent.delete_child(self)
				
				if @children
					@children.each do |child|
						if child.finished?
							delete_child(child)
						else
							parent.add_child(child)
						end
					end
					
					@children = nil
				end
				
				parent.consume
			end
		end
		
		# Traverse the tree.
		# @yield [node, level] The node and the level relative to the given root.
		def traverse(level = 0, &block)
			yield self, level
			
			@children&.each do |child|
				child.traverse(level + 1, &block)
			end
		end
		
		def stop
			@children&.each(&:stop)
		end
		
		def print_hierarchy(out = $stdout, backtrace: true)
			self.traverse do |node, level|
				indent = "\t" * level
				
				out.puts "#{indent}#{node}"
				
				print_backtrace(out, indent, node) if backtrace
			end
		end
		
		private
		
		def print_backtrace(out, indent, node)
			if backtrace = node.backtrace
				backtrace.each_with_index do |line, index|
					out.puts "#{indent}#{index.zero? ? "→ " : "  "}#{line}"
				end
			end
		end
	end
end
