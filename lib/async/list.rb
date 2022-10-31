# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

module Async
	class List
		def initialize
			@head = self
			@tail = self
		end
		
		# @private
		attr_accessor :head
		
		# @private
		attr_accessor :tail
		
		# Append a node to the end of the list.
		def append(node)
			if node.head
				raise ArgumentError, "Node is already in a list!"
			end
			
			node.tail = self
			@head.tail = node
			node.head = @head
			@head = node
			
			return node
		end
		
		def prepend(node)
			if node.head
				raise ArgumentError, "Node is already in a list!"
			end
			
			node.head = self
			@tail.head = node
			node.tail = @tail
			@tail = node
			
			return node
		end
		
		def delete(node)
			# One downside of this interface is we don't actually check if the node is part of the list defined by `self`. This means that there is a potential for a node to be deleted from a different list using this method, which in can throw off book-keeping when lists track size, etc.
			
			unless node.head
				raise ArgumentError, "Node is not in a list!"
			end
			
			node.head.tail = node.tail
			node.tail.head = node.head
			
			# This marks the node as being deleted, and causes delete to fail if called a 2nd time.
			node.head = nil
			# node.tail = nil
			
			return node
		end
		
		def empty?
			@tail.equal?(self)
		end
		
		def each
			return to_enum unless block_given?
			
			current = self
			
			while true
				node = current.tail
				# binding.irb if node.nil? && !node.equal?(self)
				break if node.equal?(self)
				
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
	end
	
	class List::Node
		attr_accessor :head
		attr_accessor :tail
		
		# Delete the node from the list.
		def delete!
			@head.tail = @tail
			@tail.head = @head
			@head = nil
			
			# See above deletion implementation for more details:
			# @tail = nil
			
			return self
		end
	end
end
