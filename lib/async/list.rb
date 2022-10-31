# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2022, by Samuel Williams.

module Async
	class List
		def initialize
			@head = self
			@tail = self
			@size = 0
		end
		
		# @private
		attr_accessor :head
		
		# @private
		attr_accessor :tail
		
		attr :size
		
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
		def stack(node, &block)
			append(node)
			yield
		ensure
			remove!(node)
		end
		
		def removed(node)
			@size -= 1
			return node
		end
		
		# Remove the node if it is in the list.
		def remove?(node)
			if node.head
				remove!(node)
			end
		end
		
		# Remove the node.
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
			unless @tail.equal?(self)
				@tail
			end
		end
		
		def last
			unless @head.equal?(self)
				@head
			end
		end
	end
	
	class List::Node
		attr_accessor :head
		attr_accessor :tail
	end
end
