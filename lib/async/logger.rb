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
	class Logger
		LEVELS = {debug: 0, info: 1, warn: 2, error: 3, fatal: 4}
		
		LEVELS.each do |name, level|
			self.const_set(name.to_s.upcase, level)
			
			self.define_method(name) do |*arguments, &block|
				if level >= @level
					self.format(*arguments, &block)
				end
			end
		end
		
		def initialize(output, level: 0)
			@output = output
			@level = level
			@start = Time.now
			
			@subjects = {}
		end
		
		attr_accessor :level
		
		def enable(subject)
			@subjects[subject] = true
		end
		
		def disable(subject)
			@subjects[subject] = false
		end
		
		def format(subject, *arguments, &block)
			prefix = time_offset_prefix
			
			if block_given?
				arguments << yield
			end
			
			arguments.each do |argument|
				format_argument(prefix, argument)
			end
		end
		
		def format_argument(prefix, argument)
			if argument.is_a? Exception
				format_exception(prefix, argument)
			else
				format_value(prefix, argument)
			end
		end
		
		def format_exception(prefix, exception)
			@output.puts "#{prefix}: #{exception.class}: #{exception}"
			indent = (" " * prefix.size) + "| "
			
			exception.backtrace.each do |line|
				@output.puts "#{indent}\t#{line}"
			end
			
			if exception.cause
				@output.puts "... caused by:"
				
				format_exception("...".rjust(prefix.size), exception.cause)
			end
		end
		
		def format_value(prefix, value)
			@output.puts "#{prefix}#{value.inspect}"
		end
		
		def time_offset_prefix
			offset = Time.now - @start
			minutes = (offset/60).floor
			seconds = (offset - (minutes*60))
			
			if minutes > 0
				"#{minutes}m#{seconds.floor}s"
			else
				"#{seconds.round(2)}s"
			end.rjust(6)
		end
	end
	
	# The Async Logger class.
	class << self
		# @attr logger [Logger] the global logger instance used by `Async`.
		attr :logger
	
		# Set the default log level based on `$DEBUG` and `$VERBOSE`.
		def default_log_level
			if $DEBUG
				Logger::DEBUG
			elsif $VERBOSE
				Logger::INFO
			else
				Logger::WARN
			end
		end
	end

	# Create the logger instance.
	@logger = Logger.new($stderr, level: self.default_log_level)
end
