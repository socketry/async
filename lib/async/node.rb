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
			# The list behaves like a list node, so @tail points to the next item (the first one) and head points to the previous item (the last one). This may be slightly confusing but it makes the interface more natural.
			@head = nil
			@tail = nil
			@size = 0
		end
		
		attr :size
		
		attr_accessor :head
		attr_accessor :tail
		
		# Inserts an item at the end of the list.
		def insert(item)
			unless @tail
				@tail = item
				@head = item
				
				# Consistency:
				item.head = nil
				item.tail = nil
			else
				@head.tail = item
				item.head = @head
				
				# Consistency:
				item.tail = nil
				
				@head = item
			end
			
			@size += 1
			
			return self
		end
		
		def delete(item)
			if @tail.equal?(item)
				@tail = @tail.tail
			else
				item.head.tail = item.tail
			end
			
			if @head.equal?(item)
				@head = @head.head
			else
				item.tail.head = item.head
			end
			
			item.head = nil
			item.tail = nil
			
			@size -= 1
			
			return self
		end
		
		def each(&block)
			return to_enum unless block_given?
			
			current = self
			while node = current.tail
				yield node
				
				# If the node has deleted itself or any subsequent node, it will no longer be the next node, so don't use it for continued traversal:
				if current.tail.equal?(node)
					current = node
				end
			end
		end
		
		def include?(needle)
			self.each do |item|
				return true if needle.equal?(item)
			end
			
			return false
		end
		
		def first
			@tail
		end
		
		def last
			@head
		end
		
		def empty?
			@tail.nil?
		end
		
		def nil?
			@tail.nil?
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
							# In theory we don't need to do this... because we are throwing away the list. However, if you don't correctly update the list when moving the child to the parent, it foobars the enumeration, and subsequent nodes will be skipped, or in the worst case you might start enumerating the parents nodes.
							delete_child(child)
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
		
		# Immediately terminate all children tasks, including transient tasks.
		# Internally invokes `stop(false)` on all children.
		def terminate
			# Attempt to stop the current task immediately, and all children:
			stop(false)
			
			# If that doesn't work, take more serious action:
			@children&.each do |child|
				child.terminate
			end
		end
		
		# Attempt to stop the current node immediately, including all non-transient children.
		# Invokes {#stop_children} to stop all children.
		# @parameter later [Boolean] Whether to defer stopping until some point in the future.
		def stop(later = false)
			# The implementation of this method may defer calling `stop_children`.
			stop_children(later)
		end
		
		# Attempt to stop all non-transient children.
		private def stop_children(later = false)
			@children&.each do |child|
				child.stop(later) unless child.transient?
			end
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
