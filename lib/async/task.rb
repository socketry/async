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

require 'fiber'
require 'forwardable'

require_relative 'node'
require_relative 'condition'

module Async
	# Raised when a task is explicitly stopped.
	class Stop < Exception
	end

	# A task represents the state associated with the execution of an asynchronous
	# block.
	class Task < Node
		extend Forwardable
	
		# Yield the unerlying `result` for the task. If the result
		# is an Exception, then that result will be raised an its
		# exception.
		# @return [Object] result of the task
		# @raise [Exception] if the result is an exception
		# @yield [result] result of the task if a block if given.
		def self.yield
			if block_given?
				result = yield
			else
				result = Fiber.yield
			end
			
			if result.is_a? Exception
				raise result
			else
				return result
			end
		end
		
		# Create a new task.
		# @param reactor [Async::Reactor] the reactor this task will run within.
		# @param parent [Async::Task] the parent task.
		def initialize(reactor, parent = Task.current?)
			super(parent || reactor)
			
			@reactor = reactor
			
			@status = :initialized
			@result = nil
			
			@finished = nil
			
			@fiber = Fiber.new do |*args|
				set!
				
				begin
					@result = yield(self, *args)
					@status = :complete
					# Async.logger.debug("Task #{self} completed normally.")
				rescue Stop
					@status = :stop
					# Async.logger.debug("Task #{self} stopped: #{$!}")
					Async.logger.debug(self) {$!}
				rescue Exception => error
					@result = error
					@status = :failed
					Async.logger.debug(self) {$!}
					raise
				ensure
					# Async.logger.debug("Task #{self} closing: #{$!}")
					finish!
				end
			end
		end
		
		def to_s
			"<#{self.description} status=#{@status}>"
		end
		
		# @attr ios [Reactor] The reactor the task was created within.
		attr :reactor
		def_delegators :@reactor, :timeout, :sleep
		
		# Yield back to the reactor and allow other fibers to execute.
		def yield
			reactor.yield
		end
		
		# @attr fiber [Fiber] The fiber which is being used for the execution of this task.
		attr :fiber
		def_delegators :@fiber, :alive?
		
		# @attr status [Symbol] The status of the execution of the fiber, one of `:running`, `:complete`, `:stopped`, or `:failed`.
		attr :status
		
		# Resume the execution of the task.
		def run(*args)
			if @status == :initialized
				@status = :running
				@fiber.resume(*args)
			else
				raise RuntimeError, "Task already running!"
			end
		end
		
		def async(*args, &block)
			task = Task.new(@reactor, self, &block)
			
			task.run(*args)
			
			return task
		end
		
		# Retrieve the current result of the task. Will cause the caller to wait until result is available.
		# @raise [RuntimeError] if the task's fiber is the current fiber.
		# @return [Object]
		def result
			raise RuntimeError.new("Cannot wait on own fiber") if Fiber.current.equal?(@fiber)
			
			if running?
				@finished ||= Condition.new
				@finished.wait
			else
				Task.yield {@result}
			end
		end
		
		alias wait result
	
		# Stop the task and all of its children.
		# @return [void]
		def stop
			@children.each(&:stop)
			
			if @fiber.alive?
				@fiber.resume(Stop.new)
			end
		end
	
		# Lookup the {Task} for the current fiber. Raise `RuntimeError` if none is available.
		# @return [Async::Task]
		# @raise [RuntimeError] if task was not {set!} for the current fiber.
		def self.current
			Thread.current[:async_task] or raise RuntimeError, "No async task available!"
		end
	
		# Check if there is a task defined for the current fiber.
		# @return [Async::Task, nil]
		def self.current?
			Thread.current[:async_task]
		end
		
		# Check if the task is running.
		# @return [Boolean]
		def running?
			@status == :running
		end
	
		# Whether we can remove this node from the reactor graph.
		# @return [Boolean]
		def finished?
			super && @status != :running
		end
	
		private
	
		# Finish the current task, and all bound bound IO objects.
		def finish!
			# Attempt to remove this node from the task tree.
			consume
			
			# If this task was being used as a future, signal completion here:
			if @finished
				@finished.signal(@result)
			end
		end
	
		# Set the current fiber's `:async_task` to this task.
		def set!
			# This is actually fiber-local:
			Thread.current[:async_task] = self
		end
	end
end
