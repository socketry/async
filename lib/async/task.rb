# frozen_string_literal: true

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
		class Later
			def initialize(task)
				@task = task
			end
			
			def alive?
				true
			end
			
			def resume
				@task.stop
			end
		end
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
		def initialize(reactor, parent = Task.current?, logger: nil, finished: nil, **options, &block)
			super(parent || reactor, **options)
			
			@reactor = reactor
			
			@status = :initialized
			@result = nil
			@finished = finished
			
			@logger = logger || @parent.logger
			
			@fiber = make_fiber(&block)
		end
		
		attr :logger
		
		if Fiber.current.respond_to?(:backtrace)
			def backtrace(*arguments)
				@fiber&.backtrace(*arguments)
			end
		end
		
		def to_s
			"\#<#{self.description} (#{@status})>"
		end
		
		# @attr ios [Reactor] The reactor the task was created within.
		attr :reactor
		
		def_delegators :@reactor, :with_timeout, :sleep
		
		# Yield back to the reactor and allow other fibers to execute.
		def yield
			Task.yield{reactor.yield}
		end
		
		# @attr fiber [Fiber] The fiber which is being used for the execution of this task.
		attr :fiber
		
		def alive?
			@fiber&.alive?
		end
		
		# @attr status [Symbol] The status of the execution of the fiber, one of `:initialized`, `:running`, `:complete`, `:stopped` or `:failed`.
		attr :status
		
		# Begin the execution of the task.
		def run(*arguments)
			if @status == :initialized
				@status = :running
				
				@fiber.resume(*arguments)
			else
				raise RuntimeError, "Task already running!"
			end
		end
		
		def async(*arguments, **options, &block)
			task = Task.new(@reactor, self, **options, &block)
			
			task.run(*arguments)
			
			return task
		end
		
		# Retrieve the current result of the task. Will cause the caller to wait until result is available.
		# @raise [RuntimeError] if the task's fiber is the current fiber.
		# @return [Object] the final expression/result of the task's block.
		def wait
			raise RuntimeError, "Cannot wait on own fiber" if Fiber.current.equal?(@fiber)
			
			if running?
				@finished ||= Condition.new
				@finished.wait
			else
				Task.yield{@result}
			end
		end
		
		# Deprecated.
		alias result wait
		# Soon to become attr :result
		
		# Stop the task and all of its children.
		def stop(later = false)
			if self.stopped?
				# If we already stopped this task... don't try to stop it again:
				return
			end
			
			if self.running?
				if self.current?
					if later
						@reactor << Stop::Later.new(self)
					else
						raise Stop, "Stopping current task!"
					end
				elsif @fiber&.alive?
					begin
						@fiber.resume(Stop.new)
					rescue FiberError
						@reactor << Stop::Later.new(self)
					end
				end
			else
				# We are not running, but children might be, so transition directly into stopped state:
				stop!
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
		
		def current?
			self.equal?(Thread.current[:async_task])
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
		
		def failed?
			@status == :failed
		end
		
		def stopping?
			@status == :stopping
		end
		
		def stopped?
			@status == :stopped
		end
		
		def complete?
			@status == :complete
		end
		
		private
		
		# This is a very tricky aspect of tasks to get right. I've modelled it after `Thread` but it's slightly different in that the exception can propagate back up through the reactor. If the user writes code which raises an exception, that exception should always be visible, i.e. cause a failure. If it's not visible, such code fails silently and can be very difficult to debug.
		def fail!(exception = false, propagate = true)
			@status = :failed
			@result = exception
			
			if exception
				if propagate
					raise exception
				elsif @finished.nil?
					# If no one has called wait, we log this as a warning:
					Console.logger.warn(self, "Task may have ended with unhandled exception.", exception)
				else
					Console.logger.debug(self, exception)
				end
			end
		end
		
		def stop!
			# logger.debug(self) {"Task was stopped with #{@children&.size.inspect} children!"}
			@status = :stopped
			
			stop_children(true)
		end
		
		def make_fiber(&block)
			Fiber.new do |*arguments|
				set!
				
				begin
					@result = yield(self, *arguments)
					@status = :complete
					# Console.logger.debug(self) {"Task was completed with #{@children.size} children!"}
				rescue Stop
					stop!
				rescue StandardError => error
					fail!(error, false)
				rescue Exception => exception
					fail!(exception, true)
				ensure
					# Console.logger.debug(self) {"Task ensure $!=#{$!} with #{@children.size} children!"}
					finish!
				end
			end
		end
		
		# Finish the current task, and all bound bound IO objects.
		def finish!
			# Allow the fiber to be recycled.
			@fiber = nil
			
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
			Console.logger = @logger if @logger
		end
	end
end
