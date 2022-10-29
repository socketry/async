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
			node.tail = self
			@head.tail = node
			node.head = @head
			@head = node
			
			return node
		end
		
		def prepend(node)
			node.head = self
			@tail.head = node
			node.tail = @tail
			@tail = node
			
			return node
		end
		
		def delete(node)
			node.head.tail = node.tail
			node.tail.head = node.head
			node.head = nil
			node.tail = nil
		end
		
		# Delete the node from the list.
		def delete!
			@head.tail = @tail
			@tail.head = @head
			@head = nil
			@tail = nil
			
			return self
		end
		
		def empty?
			@tail == self
		end
		
		def each
			return to_enum unless block_given?
			
			current = self
			
			while true
				node = current.tail
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
		
		def empty?
			@tail == self
		end
		
		def nil?
			@tail == self
		end
	end
end
