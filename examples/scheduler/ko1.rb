#!/usr/bin/env ruby

require 'fiber'
require 'io/nonblock'
require 'open-uri'

class Scheduler
	def initialize
		@ready = []
		@waiting = [] # [[f, type, opts], ...]
	end
	
	def now
		Process.clock_gettime(Process::CLOCK_MONOTONIC)
	end
	
	def wait_readable_fd(fd)
		wait_readable(::IO.for_fd(fd, autoclose: false))
	end
	
	def wait_readable(io)
		p wait_readable: io
		Fiber.yield :wait_readable, io
		
		true
	end
	
	def wait_any(io, events, timeout)
		p [:wait_any, io, events, timeout]
		case events
		when IO::WAIT_READABLE
			Fiber.yield :wait_readable, io
		when IO::WAIT_WRITABLE
			Fiber.yield :wait_writable, io
		when IO::WAIT_READABLE | IO::WAIT_WRITABLE
			Fiber.yield :wait_any, io
		end
		
		true
	end
	
	# Wrapper for rb_wait_for_single_fd(int) C function.
	def wait_for_single_fd(fd, events, duration)
		wait_any(::IO.for_fd(fd, autoclose: false), events, duration)
	end
	
	# Sleep the current task for the specified duration, or forever if not
	# specified.
	# @param duration [#to_f] the amount of time to sleep.
	def wait_sleep(duration = nil)
		Fiber.yield :sleep, self.now + duration
	end
	
	def fiber
		@ready << f = Fiber.new(blocking: false){
			yield
			:exit
		}
		f
	end
	
	def schedule_ready
		while f = @ready.shift
			wait, opts = f.resume
			case wait
			when :exit
				# ok
			else
				@waiting << [f, wait, opts]
			end
		end
	end
	
	def run
		until @ready.empty? && @waiting.empty?
			schedule_ready
			next if @waiting.empty?
			p @waiting
			wakeup_time = nil
			wakeup_fiber = nil
			rs = []
			ws = []
			now = self.now
			@waiting.each{|f, type, opt|
				case type
				when :sleep
					t = opt
					if !wakeup_time || wakeup_time > t
						wakeup_time = t
						wakeup_fiber = f
					end
				when :wait_readable
					io = opt
					rs << io
				when :wait_writable
					io = opt
					ws << io
				when :wait_any
					io = opt
					rs << io
					ws << io
				end
			}
			if wakeup_time
				if wakeup_time > now
					dur = wakeup_time - self.now
				else
					@ready << wakeup_fiber
					@waiting.delete_if{|f,| f == wakeup_fiber}
				end
			end
			pp dur
			rs, ws, es = IO.select rs, ws, nil, dur
			pp selected: [rs, ws, es]
			[*rs, *ws].each{|io|
				@waiting.delete_if{|f, type, opt|
					if opt == io
						p [:ready, f, io]
						@ready << f
						true
					end
				}
			}
			pp after: @waiting
		end
	end
	
	def enter_blocking_region
		#pp caller(0)
	end
	
	def exit_blocking_region
		#pp caller(0)
	end
end

Thread.current.scheduler = Scheduler.new

Fiber do
	URI.open('http://www.ruby-lang.org/'){|f| p f.gets}
end

Thread.current.scheduler.run
