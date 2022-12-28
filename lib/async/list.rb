# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

module Async
	# A general doublely linked list. This is used internally by {Async::Barrier} and {Async::Condition} to manage child tasks.
	class List
		# Initialize a new, empty, list.
		def initialize
			@head = self
			@tail = self
			@size = 0
		end
		
		# Print a short summary of the list.
		def to_s
			sprintf("#<%s:0x%x size=%d>", self.class.name, object_id, @size)
		end
		
		alias inspect to_s
		
		# Fast, safe, unbounded accumulation of children.
		def to_a
			items = []
			current = self
			
			while current.tail != self
				unless current.tail.is_a?(Iterator)
					items << current.tail
				end
				
				current = current.tail
			end
			
			return items
		end
		
		# Points at the end of the list.
		attr_accessor :head
		
		# Points at the start of the list.
		attr_accessor :tail
		
		attr :size
		
		# A callback that is invoked when an item is added to the list.
		def added(node)
			@size += 1
			return node
		end
		
		# Append a node to the end of the list.
		def append(node)
			if node.head
				raise ArgumentError, "Node is already in a list!"
			end
			
			node.tail = self
			@head.tail = node
			node.head = @head
			@head = node
			
			return added(node)
		end
		
		def prepend(node)
			if node.head
				raise ArgumentError, "Node is already in a list!"
			end
			
			node.head = self
			@tail.head = node
			node.tail = @tail
			@tail = node
			
			return added(node)
		end
		
		# Add the node, yield, and the remove the node.
		# @yields {|node| ...} Yields the node.
		# @returns [Object] Returns the result of the block.
		def stack(node, &block)
			append(node)
			return yield(node)
		ensure
			remove!(node)
		end
		
		# A callback that is invoked when an item is removed from the list.
		def removed(node)
			@size -= 1
			return node
		end
		
		# Remove the node if it is in a list.
		#
		# You should be careful to only remove nodes that are part of this list.
		#
		# @returns [Node] Returns the node if it was removed, otherwise nil.
		def remove?(node)
			if node.head
				return remove!(node)
			end
			
			return nil
		end
		
		# Remove the node. If it was already removed, this will raise an error.
		#
		# You should be careful to only remove nodes that are part of this list.
		#
		# @raises [ArgumentError] If the node is not part of this list.
		# @returns [Node] Returns the node if it was removed, otherwise nil.
		def remove(node)
			# One downside of this interface is we don't actually check if the node is part of the list defined by `self`. This means that there is a potential for a node to be removed from a different list using this method, which in can throw off book-keeping when lists track size, etc.
			unless node.head
				raise ArgumentError, "Node is not in a list!"
			end
			
			remove!(node)
		end
		
		private def remove!(node)
			node.head.tail = node.tail
			node.tail.head = node.head
			
			# This marks the node as being removed, and causes remove to fail if called a 2nd time.
			node.head = nil
			# node.tail = nil
			
			return removed(node)
		end
		
		# @returns [Boolean] Returns true if the list is empty.
		def empty?
			@size == 0
		end
		
		# def validate!(node = nil)
		# 	previous = self
		# 	current = @tail
		# 	found = node.equal?(self)
			
		# 	while true
		# 		break if current.equal?(self)
				
		# 		if current.head != previous
		# 			raise "Invalid previous linked list node!"
		# 		end
				
		# 		if current.is_a?(List) and !current.equal?(self)
		# 			raise "Invalid list in list node!"
		# 		end
				
		# 		if node
		# 			found ||= current.equal?(node)
		# 		end
				
		# 		previous = current
		# 		current = current.tail
		# 	end
			
		# 	if node and !found
		# 		raise "Node not found in list!"
		# 	end
		# end
		
		# Iterate over each node in the linked list. It is generally safe to remove the current node, any previous node or any future node during iteration.
		#
		# @yields {|node| ...} Yields each node in the list.
		# @returns [List] Returns self.
		def each(&block)
			return to_enum unless block_given?
			
			Iterator.each(self, &block)
			
			return self
		end
		
		# Determine whether the given node is included in the list. 
		#
		# @parameter needle [Node] The node to search for.
		# @returns [Boolean] Returns true if the node is in the list.
		def include?(needle)
			self.each do |item|
				return true if needle.equal?(item)
			end
			
			return false
		end
		
		# @returns [Node] Returns the first node in the list, if it is not empty.
		def first
			# validate!
			
			current = @tail
			
			while !current.equal?(self)
				if current.is_a?(Iterator)
					current = current.tail
				else
					return current
				end
			end
			
			return nil
		end
		
		# @returns [Node] Returns the last node in the list, if it is not empty.
		def last
			# validate!
			
			current = @head
			
			while !current.equal?(self)
				if current.is_a?(Iterator)
					current = current.head
				else
					return current
				end
			end
			
			return nil
		end
		
		def shift
			if node = first
				remove!(node)
			end
		end
		
		# A linked list Node.
		class Node
			attr_accessor :head
			attr_accessor :tail
			
			alias inspect to_s
		end
		
		class Iterator < Node
			def initialize(list)
				@list = list
				
				# Insert the iterator as the first item in the list:
				@tail = list.tail
				@tail.head = self
				list.tail = self
				@head = list
			end
			
			def remove!
				@head.tail = @tail
				@tail.head = @head
				@head = nil
				@tail = nil
				@list = nil
			end
			
			def move_next
				# Move to the next item (which could be an iterator or the end):
				@tail.head = @head
				@head.tail = @tail
				@head = @tail
				@tail = @tail.tail
				@head.tail = self
				@tail.head = self
			end
			
			def move_current
				while true
					# Are we at the end of the list?
					if @tail.equal?(@list)
						return nil
					end
					
					if @tail.is_a?(Iterator)
						move_next
					else
						return @tail
					end
				end
			end
			
			def each
				while current = move_current
					yield current
					
					if current.equal?(@tail)
						move_next
					end
				end
			end
			
			def self.each(list, &block)
				return if list.empty?
				
				iterator = Iterator.new(list)
				
				iterator.each(&block)
			ensure
				iterator&.remove!
			end
		end
		
		private_constant :Iterator
	end
end
