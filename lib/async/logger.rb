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

require_relative 'terminal'

# Downstream gems often use `Logger:::LEVEL` constants, so we pull this in so they are available. That being said, the code should be fixed.
require 'logger'

module Async
	class Logger
		class Buffer < StringIO
			def initialize(prefix = nil)
				@prefix = prefix
				
				super()
			end
			
			def puts(*args, prefix: @prefix)
				args.each do |arg|
					self.write(prefix) if prefix
					
					super(arg)
				end
			end
		end
		
		LEVELS = {debug: 0, info: 1, warn: 2, error: 3, fatal: 4}
		
		LEVELS.each do |name, level|
			const_set(name.to_s.upcase, level)
			
			define_method(name) do |subject = nil, *arguments, &block|
				enabled = @subjects[subject.class]
				
				if enabled == true or (enabled != false and level >= @level)
					self.format(subject, *arguments, &block)
				end
			end
			
			define_method("#{name}!") do
				@level = level
			end
		end
		
		def initialize(output, level: 1)
			@output = output
			@level = level
			@start = Time.now
			
			@terminal = Terminal.new(output)
			@reset_style = @terminal.reset
			@prefix_style = @terminal.color(Terminal::Colors::CYAN)
			@subject_style = @terminal.color(nil, nil, Terminal::Attributes::BOLD)
			@exception_title_style = @terminal.color(Terminal::Colors::RED, nil, Terminal::Attributes::BOLD)
			@exception_details_style = @terminal.color(Terminal::Colors::YELLOW)
			@exception_line_style = @terminal.color(Terminal::Colors::RED)
			
			@subjects = {}
		end
		
		attr :level
		
		def level= value
			if value.is_a? Symbol
				@level = LEVELS[value]
			else
				@level = value
			end
		end
		
		def enabled?(subject)
			@subjects[subject.class] == true
		end
		
		def enable(subject)
			@subjects[subject.class] = true
		end
		
		def disable(subject)
			@subjects[subject.class] = false
		end
		
		def log(level, *arguments, &block)
			unless level.is_a? Symbol
				level = LEVELS[level]
			end
			
			self.send(level, *arguments, &block)
		end
		
		def format(subject = nil, *arguments, &block)
			prefix = time_offset_prefix
			indent = " " * prefix.size
			
			buffer = Buffer.new("#{indent}| ")
			
			if subject
				format_subject(prefix, subject, output: buffer)
			end
			
			arguments.each do |argument|
				format_argument(argument, output: buffer)
			end
			
			if block_given?
				if block.arity.zero?
					format_argument(yield, output: buffer)
				else
					yield(buffer, @terminal)
				end
			end
			
			@output.write buffer.string
		end
		
		def format_argument(argument, output: @output)
			if argument.is_a? Exception
				format_exception(argument, output: output)
			else
				format_value(argument, output: output)
			end
		end
		
		def format_exception(exception, prefix = nil, pwd: Dir.pwd, output: @output)
			lines = exception.message.lines.map(&:chomp)
			
			output.puts " #{prefix}#{@exception_title_style}#{exception.class}#{@reset_style}: #{lines.shift}"
			
			lines.each do |line|
				output.puts "   #{@exception_details_style}" + line + @reset_style
			end
			
			exception.backtrace.each_with_index do |line, index|
				path, offset, message = line.split(":")
				
				# Make the path a bit more readable
				path.gsub!(/^#{pwd}\//, "./")
				
				output.puts " #{index == 0 ? "→" : " "} #{@exception_line_style}#{path}:#{offset}#{@reset_style} #{message}"
			end
			
			if exception.cause
				format_exception(exception.cause, "Caused by ", pwd: pwd, output: output)
			end
		end
		
		def format_subject(prefix, subject, output: @output)
			output.puts "#{@subject_style}#{subject}#{@reset_style}", prefix: "#{@prefix_style}#{prefix}: "
		end
		
		def format_value(value, output: @output)
			string = value.to_s
			
			string.each_line do |line|
				output.puts "#{line}"
			end
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
