

require 'fiber'

class IO
	READABLE = 1
	WRITABLE = 2
	
	# rb_wait_for_single_fd (int fd, int events, struct timeval *tv)
	def self.wait(descriptor, events, duration)
		fiber = Fiber.current
		reactor = fiber.reactor
		
		monitor = reactor.add_io(fiber, descriptor, state)
		
		fiber.timeout(duration) do
			result = Fiber.yield
			raise result if result.is_a? Exception
		end
		
		return result
	ensure
		reactor.remove_io(monitor)
	end
	
	def wait_readable(duration = nil)
		wait_any(READABLE)
	end
	
	def wait_writable(duration = nil)
		wait_any(WRITABLE)
	end
	
	def wait_until(events = READABLE|WRITABLE, duration = nil)
		IO.wait_for_io(self.fileno, events, duration)
	end
end

class Fiber
	# Raised when a task times out.
	class TimeoutError < RuntimeError
	end
	
	# This should be inherited by nested fibers.
	attr :reactor
	
	def timeout(duration)
		reactor = self.reactor
		backtrace = caller
		
		timer = reactor.add_timer(duration) do
			if self.alive?
				error = Fiber::TimeoutError.new("execution expired")
				error.set_backtrace backtrace
				self.resume error
			end
		end
		
		yield
	ensure
		reactor.cancel_timer(timer)
	end
end

# Can be standard implementation, but could also be provided by external gem/library.
class Fiber::Reactor
	# Add IO to the reactor. The reactor will call `fiber.resume` when the event is triggered.
	# Returns an opaque monitor object which can be passed to `remove_io` to stop waiting for events.
	def add_io(fiber, io, state)
		# The motivation for add_io and remove_io is that it's how a lot of the underlying APIs work, where remove_io just takes the file descriptor.
		# It also avoids the need for any memory allocation, and maps well to how it's typically used (i.e. in an implementation of `IO#read`).
		# An efficient implementation might do it's job and then just:
		return io
	end
	
	def remove_io(monitor)
	end
	
	# The reactor will call the block at some point after duration time has elapsed.
	# Returns an opaque timer object which can be passed to `cancel_timer` to avoid this happening.
	def add_timer(duration, &block)
	end
	
	def cancel_timer(timer)
	end
	
	# Run until idle (no registered io/timers), or duration time has passed if specified.
	def run(duration = nil)
	end
	
	# Stop the reactor as soon as possible. Can be called from another thread.
	def stop
	end
	
	def close
		# Close the reactor so it can no longer be used.
	end
end

# Basic non-blocking task:
reactor = Fiber::Reactor.new

# User could provide their own reactor, it might even do other things, but the basic interface above should continue to work.

Fiber.new(reactor: reactor) do
	# Blocking operations call Fiber.yield, which goes to...
end.resume

# ...here, which starts running the reactor which can also be controlled (e.g. duration, stopping)
reactor.run

# Here is a rough outline of the reactor concept implementation using NIO4R
# Can be standard implementation, but could also be provided by external gem/library.
class NIO::Reactor
	def initialize
		@selector = NIO::Selector.new
		@timers = Timers::Group.new
		
		@stopped = true
	end
	
	EVENTS = [
		:r,
		:w,
		:rw
	]
	
	def add_io(fiber, io, event)
		monitor = @selector.register(io, EVENTS[event])
		monitor.value = fiber
	end
	
	def remove_io(monitor)
		monitor.cancel
	end
	
	# The reactor will call `fiber.resume(Fiber::TimeoutError)` at some point after duration time has elapsed.
	# Returns an opaque timer object which can be passed to `cancel_timer` to avoid this happening.
	def add_timer(fiber, duration)
		@timers.after(duration, &block)
	end
	
	def cancel_timer(timer)
		timer.cancel
	end
	
	# Run until idle (no registered io/timers), or duration time has passed if specified.
	def run(duration = nil)
		@timers.wait do |interval|
			# - nil: no timers
			# - -ve: timers expired already
			# -   0: timers ready to fire
			# - +ve: timers waiting to fire
			interval = 0 if interval && interval < 0
			
			# If there is nothing to do, then finish:
			return if @fibers.empty? && interval.nil?
			
			if monitors = @selector.select(interval)
				monitors.each do |monitor|
					if fiber = monitor.value
						fiber.resume
					end
				end
			end
		end until @stopped
	end
	
	def stop
		@stopped = true
		@selector.wakeup
	end
	
	def close
		@seletor.close
	end
end

