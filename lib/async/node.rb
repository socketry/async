# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2022, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2022, by Shannon Skipper.

require_relative 'list'

module Async
	# A list of children tasks.
	class Children < List
		def initialize
			super
			
			@size = 0
			@transient_count = 0
		end
		
		attr :size
		
		# Does this node have (direct) transient children?
		def transients?
			@transient_count > 0
		end
		
		def append(node)
			added(super)
		end
		
		undef prepend
		
		def delete(node)
			removed(super)
		end
		
		def finished?
			@size == @transient_count
		end
		
		def nil?
			empty?
		end
		
		private
		
		def added(node)
			if node.transient?
				@transient_count += 1
			end
			
			@size += 1
		end
		
		def removed(node)
			if node.transient?
				@transient_count -= 1
			end
			
			@size -= 1
		end
	end
	
	# A node in a tree, used for implementing the task hierarchy.
	class Node
		# Create a new node in the tree.
		# @parameter parent [Node | Nil] This node will attach to the given parent.
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
		
		# @returns [Node] the root node in the hierarchy.
		def root
			@parent&.root || self
		end
		
		# @private
		attr_accessor :head
		
		# @private
		attr_accessor :tail
		
		# @attribute [Node] The parent node.
		attr :parent
		
		# @attribute children [Children | Nil] Optional list of children.
		attr :children
		
		# A useful identifier for the current node.
		attr :annotation
		
		# Whether there are children?
		def children?
			@children && !@children.empty?
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
			@object_name ||= "#{self.class}:#{format '%#018x', object_id}#{@transient ? ' transient' : nil}"
			
			if @annotation
				"#{@object_name} #{@annotation}"
			elsif line = self.backtrace(0, 1)&.first
				"#{@object_name} #{line}"
			else
				@object_name
			end
		end
		
		def backtrace(*arguments)
			nil
		end
		
		def to_s
			"\#<#{self.description}>"
		end
		
		alias inspect to_s
		
		# Change the parent of this node.
		# @parameter parent [Node | Nil] the parent to attach to, or nil to detach.
		# @returns [Node] Itself.
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
		
		protected def set_parent(parent)
			@parent = parent
		end
		
		protected def add_child(child)
			@children ||= Children.new
			@children.append(child)
			child.set_parent(self)
		end
		
		protected def delete_child(child)
			@children.delete(child)
			child.set_parent(nil)
		end
		
		# Whether the node can be consumed safely. By default, checks if the
		# children set is empty.
		# @returns [Boolean]
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
		
		# Traverse the task tree.
		# @yields {|node, level| ...} The node and the level relative to the given root.
		def traverse(&block)
			return enum_for(:traverse) unless block_given?
			
			self.traverse_recurse(&block)
		end
		
		protected def traverse_recurse(level = 0, &block)
			yield self, level
			
			@children&.each do |child|
				child.traverse_recurse(level + 1, &block)
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
		
		def stopped?
			@children.nil?
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
