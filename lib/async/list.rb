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
			@tail.equal?(self)
		end
		
		private def validate!(node = nil)
			previous = self
			current = @tail
			found = node.equal?(self)
			
			while true
				break if current.equal?(self)
				
				if current.head != previous
					raise "Invalid previous linked list node!"
				end
				
				if current.is_a?(List) and !current.equal?(self)
					raise "Invalid list in list node!"
				end
				
				if node
					found ||= current.equal?(node)
				end
				
				previous = current
				current = current.tail
			end
			
			if node and !found
				raise "Node not found in list!"
			end
		end
		
		# Iterate over each node in the linked list. It is generally safe to remove the current node, any previous node or any future node during iteration.
		#
		# @yields {|node| ...} Yields each node in the list.
		# @returns [List] Returns self.
		def each
			return to_enum unless block_given?
			
			current = self
			
			$stderr.puts "-> each #{self}", caller
			while true
				validate!(current)
				
				node = current.tail
				break if node.equal?(self)
				
				yield node
				
				# If the node has deleted itself or any subsequent node, it will no longer be the next node, so don't use it for continued traversal:
				if current.tail.equal?(node)
					current = node
				end
			end
			
			return self
		ensure
			$stderr.puts "<- each #{self}"
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
			unless @tail.equal?(self)
				@tail
			end
		end
		
		# @returns [Node] Returns the last node in the list, if it is not empty.
		def last
			unless @head.equal?(self)
				@head
			end
		end
	end
	
	# A linked list Node.
	class List::Node
		attr_accessor :head
		attr_accessor :tail
	end
end
