# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2017-2023, by Samuel Williams.
# Copyright, 2017, by Kent Gruber.
# Copyright, 2022, by Shannon Skipper.

require 'fiber/annotation'

require_relative 'list'

module Async
	# A list of children tasks.
	class Children < List
		def initialize
			super
			@transient_count = 0
		end
		
		# Some children may be marked as transient. Transient children do not prevent the parent from finishing.
		# @returns [Boolean] Whether the node has transient children.
		def transients?
			@transient_count > 0
		end
		
		# Whether all children are considered finished. Ignores transient children.
		def finished?
			@size == @transient_count
		end
		
		# Whether the children is empty, preserved for compatibility.
		def nil?
			empty?
		end
		
		private
		
		def added(node)
			if node.transient?
				@transient_count += 1
			end
			
			return super
		end
		
		def removed(node)
			if node.transient?
				@transient_count -= 1
			end
			
			return super
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
		
		# Whether this node has any children.
		# @returns [Boolean]
		def children?
			@children && !@children.empty?
		end
		
		# Represents whether a node is transient. Transient nodes are not considered
		# when determining if a node is finished. This is useful for tasks which are
		# internal to an object rather than explicit user concurrency. For example,
		# a child task which is pruning a connection pool is transient, because it
		# is not directly related to the parent task, and should not prevent the
		# parent task from finishing.
		def transient?
			@transient
		end
		
		def annotate(annotation)
			if block_given?
				begin
					current_annotation = @annotation
					@annotation = annotation
					return yield
				ensure
					@annotation = current_annotation
				end
			else
				@annotation = annotation
			end
		end
		
		def description
			@object_name ||= "#{self.class}:#{format '%#018x', object_id}#{@transient ? ' transient' : nil}"
			
			if annotation = self.annotation
				"#{@object_name} #{annotation}"
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
		#
		# @parameter parent [Node | Nil] The parent to attach to, or nil to detach.
		# @returns [Node] Itself.
		def parent=(parent)
			return if @parent.equal?(parent)
			
			if @parent
				@parent.remove_child(self)
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
		
		protected def remove_child(child)
			@children.remove(child)
			child.set_parent(nil)
		end
		
		# Whether the node can be consumed (deleted) safely. By default, checks if the children set is empty.
		#
		# @returns [Boolean]
		def finished?
			@children.nil? || @children.finished?
		end
		
		# If the node has a parent, and is {finished?}, then remove this node from
		# the parent.
		def consume
			if parent = @parent and finished?
				parent.remove_child(self)
				
				# If we have children, then we need to move them to our the parent if they are not finished:
				if @children
					while child = @children.shift
						if child.finished?
							child.set_parent(nil)
						else
							parent.add_child(child)
						end
					end
					
					@children = nil
				end
				
				parent.consume
			end
		end
		
		# Traverse the task tree.
		#
		# @returns [Enumerator] An enumerator which will traverse the tree if no block is given.
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
		
		# Immediately terminate all children tasks, including transient tasks. Internally invokes `stop(false)` on all children. This should be considered a last ditch effort and is used when closing the scheduler.
		def terminate
			# Attempt to stop the current task immediately, and all children:
			stop(false)
			
			# If that doesn't work, take more serious action:
			@children&.each do |child|
				child.terminate
			end
			
			return @children.nil?
		end
		
		# Attempt to stop the current node immediately, including all non-transient children. Invokes {#stop_children} to stop all children.
		#
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
