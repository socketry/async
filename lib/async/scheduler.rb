# Copyright, 2020, by Samuel G. D. Williams. <http://www.codeotaku.com>
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

require_relative 'clock'
require_relative 'interrupt'
require_relative 'node'

require 'console'
require 'event'
require 'timers'
require 'resolv'

module Async
	class Scheduler < Node
		def self.supported?
			true
		end
		
		def initialize(parent = nil, selector: nil)
			super(parent)
			
			@selector = selector || Event::Backend.new(Fiber.current)
			@timers = Timers::Group.new
			
			@ready = []
			@running = []
			
			@guard = Mutex.new
			@interrupted = false
			@blocked = 0
			@unblocked = []
			
			@loop = nil
			
			@interrupt = Interrupt.new(@selector) do |event|
				case event
				when '!'
					@interrupted = true
				end
			end
		end
		
		def set!
			Fiber.set_scheduler(self)
			@loop = Fiber.current
		end
		
		def clear!
			Fiber.set_scheduler(nil)
			@loop = nil
		end
		
		def interrupt
			@interrupt.signal('!')
		end
		
		# Schedule a fiber (or equivalent object) to be resumed on the next loop through the reactor.
		# @param fiber [#resume] The object to be resumed on the next iteration of the run-loop.
		def << fiber
			@ready << fiber
		end
		
		# Yield the current fiber and resume it on the next iteration of the event loop.
		def yield
			@ready << Fiber.current
			@loop.transfer
		end
		
		def resume(fiber, *arguments)
			if @loop
				@ready << Fiber.current
				fiber.transfer(*arguments)
			else
				@ready << fiber
			end
		end
		
		# Transfer from te calling fiber to the event loop.
		def transfer
			@loop.transfer
		end
		
		# Invoked when a fiber tries to perform a blocking operation which cannot continue. A corresponding call {unblock} must be performed to allow this fiber to continue.
		# @reentrant Not thread safe.
		def block(blocker, timeout)
			# $stderr.puts "block(#{blocker}, #{Fiber.current}, #{timeout})"
			fiber = Fiber.current
			
			if timeout
				timer = @timers.after(timeout) do
					if fiber.alive?
						fiber.transfer(false)
					end
				end
			end
			
			begin
				@blocked += 1
				@loop.transfer
			ensure
				@blocked -= 1
			end
		ensure
			timer&.cancel
		end
		
		# @reentrant Thread safe.
		def unblock(blocker, fiber)
			# $stderr.puts "unblock(#{blocker}, #{fiber})"
			
			@guard.synchronize do
				@unblocked << fiber
				@interrupt&.signal
			end
		end
		
		def kernel_sleep(duration)
			self.block(nil, duration)
		end
		
		def address_resolve(hostname)
			::Resolv.getaddresses(hostname)
		end
		
		def io_wait(io, events, timeout = nil)
			fiber = Fiber.current
			
			if timeout
				timer = @timers.after(timeout) do
					fiber.raise(TimeoutError)
				end
			end
			
			# Console.logger.info(self, "-> io_wait", fiber, io, events)
			events = @selector.io_wait(fiber, io, events)
			# Console.logger.info(self, "<- io_wait", fiber, io, events)
			
			return events
		rescue TimeoutError
			return false
		ensure
			timer&.cancel
		end
		
		# Wait for the specified process ID to exit.
		# @parameter pid [Integer] The process ID to wait for.
		# @parameter flags [Integer] A bit-mask of flags suitable for `Process::Status.wait`.
		# @returns [Process::Status] A process status instance.
		def process_wait(pid, flags)
			fiber = Fiber.current
			
			return @selector.process_wait(fiber, pid, flags)
		end
		
		# Run one iteration of the event loop.
		# @param timeout [Float | nil] the maximum timeout, or if nil, indefinite.
		# @return [Boolean] whether there is more work to do.
		def run_once(timeout = nil)
			raise "Running scheduler on non-blocking fiber!" unless Fiber.blocking?
			# Console.logger.info(self) {"@ready = #{@ready} @running = #{@running}"}
			
			if @ready.any?
				# running used to correctly answer on `finished?`, and to reuse Array object.
				@running, @ready = @ready, @running
				
				@running.each do |fiber|
					fiber.transfer if fiber.alive?
				end
				
				@running.clear
			end
			
			if @unblocked.any?
				unblocked = Array.new
				
				@guard.synchronize do
					unblocked, @unblocked = @unblocked, unblocked
				end
					
				while fiber = unblocked.pop
					fiber.transfer if fiber.alive?
				end
			end
			
			if @ready.empty? and @unblocked.empty?
				interval = @timers.wait_interval
			else
				# if there are tasks ready to execute, don't sleep:
				interval = 0
			end
			
			# If we are finished, we stop the task tree and exit:
			if self.finished?
				return false
			end
			
			# If there is no interval to wait (thus no timers), and no tasks, we could be done:
			if interval.nil?
				# Allow the user to specify a maximum interval if we would otherwise be sleeping indefinitely:
				interval = timeout
			elsif interval < 0
				# We have timers ready to fire, don't sleep in the selctor:
				interval = 0
			elsif timeout and interval > timeout
				interval = timeout
			end
			
			begin
				# Console.logger.info(self) {"@selector.select(#{interval ? interval.round(2) : 'forever'})..."}
				@selector.select(interval)
			rescue Errno::EINTR
				# Ignore.
			end
			
			@timers.fire
			
			# We check and clear the interrupted flag here:
			if @interrupted
				@interrupted = false
				
				return false
			end
			
			# The reactor still has work to do:
			return true
		end
		
		# Run the reactor until all tasks are finished. Proxies arguments to {#async} immediately before entering the loop, if a block is provided.
		def run(*arguments, **options, &block)
			raise RuntimeError, 'Reactor has been closed' if @selector.nil?
			
			initial_task = self.async(*arguments, **options, &block) if block_given?
			
			while self.run_once
				# Round and round we go!
			end
			
			return initial_task
		ensure
			Console.logger.debug(self) {"Exiting run-loop because #{$! ? $! : 'finished'}."}
		end
		
		def close
			# This is a critical step. Because tasks could be stored as instance variables, and since the reactor is (probably) going out of scope, we need to ensure they are stopped. Otherwise, the tasks will belong to a reactor that will never run again and are not stopped.
			self.terminate
			
			raise "Closing scheduler with blocked operations!" if @blocked > 0
			
			@guard.synchronize do
				@interrupt.close
				@interrupt = nil
				
				@selector.close
				@selector = nil
			end
		end
		
		def closed?
			@selector.nil?
		end
		
		def fiber(&block)
			task = Task.new(Task.current? || self, &block)
			
			task.run
			
			return task.fiber
		end
		
		# Invoke the block, but after the specified timeout, raise {TimeoutError} in any currenly blocking operation. If the block runs to completion before the timeout occurs or there are no non-blocking operations after the timeout expires, the code will complete without any exception.
		# @param duration [Numeric] The time in seconds, in which the task should complete.
		def timeout_after(timeout, exception, message, &block)
			fiber = Fiber.current
			
			timer = @timers.after(timeout) do
				if fiber.alive?
					fiber.raise(exception, message)
				end
			end
			
			yield timer
		ensure
			timer.cancel if timer
		end
	end
end
