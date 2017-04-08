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

require 'set'

module Async
	class Node
		def initialize(parent = nil)
			@children = Set.new
			@parent = nil
			
			if parent
				self.parent = parent
			end
		end
		
		attr :parent
		attr :children
		
		# Attach this node to an existing parent.
		def parent=(parent)
			if @parent
				@parent.children.delete(self)
				@parent = nil
			end
			
			if parent
				@parent = parent
				@parent.children << self
			end
		end
		
		# Fold this node into it's parent, merging all children up.
		def consume
			raise RuntimeError.new("Cannot consume top level node") unless @parent
			
			@children.each do |child|
				# TODO: We could probably make this a bit more efficient.
				child.parent = @parent
			end
			
			self.parent = nil
		end
	end
end
