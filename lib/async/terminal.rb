# Copyright, 2019, by Samuel G. D. Williams. <http://www.codeotaku.com>
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
	# Styled terminal output. **Internal Use Only**
	class Terminal
		module Attributes
			NORMAL = 0
			BOLD = 1
			FAINT = 2
			ITALIC = 3
			UNDERLINE = 4
			BLINK = 5
			REVERSE = 7
			HIDDEN = 8
		end
		
		module Colors
			BLACK = 0
			RED = 1
			GREEN = 2
			YELLOW = 3
			BLUE = 4
			MAGENTA = 5
			CYAN = 6
			WHITE = 7
			DEFAULT = 9
		end
		
		def initialize(output)
			@output = output
		end
		
		def tty?
			@output.isatty
		end
		
		def color(foreground, background = nil, attributes = nil)
			return nil unless tty?
			
			buffer = String.new
			
			buffer << "\e["
			first = true
			
			if attributes
				buffer << (attributes).to_s
				first = false
			end
			
			if foreground
				if !first
					buffer << ";" 
				else
					first = false
				end
				
				buffer << (30 + foreground).to_s
			end
			
			if background
				if !first
					buffer << ";" 
				else
					first = false
				end
				
				buffer << (40 + background).to_s
			end
			
			buffer << 'm'
			
			return buffer
		end
		
		def reset
			return nil unless tty?
			
			return "\e[0m"
		end
	end
end
