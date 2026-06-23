# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module ForkDiagnostics
	def self.before_fork(label)
		return unless ENV["FORK_DIAGNOSTICS"]
		
		$stderr.puts "=== fork diagnostics: #{label} ==="
		
		if ENV["GC_BEFORE_FORK"]
			dump_state("before GC")
			
			$stderr.puts "GC.start before fork..."
			GC.start(full_mark: true, immediate_sweep: true)
			
			dump_state("after GC")
		else
			dump_state
		end
		
		$stderr.puts "=== end fork diagnostics: #{label} ==="
	end
	
	def self.dump_state(label = nil)
		$stderr.puts "--- #{label} ---" if label
		
		dump_threads
		dump_fibers
		dump_ios
		dump_file_descriptors
	end
	
	def self.dump_threads
		threads = Thread.list
		$stderr.puts "Thread.list count=#{threads.size}"
		
		threads.each_with_index do |thread, index|
			backtrace = thread.backtrace&.first
			
			$stderr.puts "  thread[#{index}] object_id=#{thread.object_id} current=#{thread == Thread.current} status=#{thread.status.inspect} alive=#{thread.alive?} report_on_exception=#{thread.report_on_exception} backtrace=#{backtrace.inspect}"
		end
	end
	
	def self.dump_fibers
		fibers = []
		ObjectSpace.each_object(Fiber) do |fiber|
			fibers << fiber
		end
		
		$stderr.puts "ObjectSpace.each_object(Fiber) count=#{fibers.size}"
		
		backtrace_limit = Integer(ENV.fetch("FORK_DIAGNOSTICS_FIBER_BACKTRACE_LIMIT", "8"))
		
		fibers.sort_by(&:object_id).each_with_index do |fiber, index|
			current = fiber == Fiber.current
			alive = safe {fiber.alive?}
			blocking = fiber.respond_to?(:blocking?) ? safe {fiber.blocking?} : nil
			async_task = fiber.respond_to?(:async_task) ? describe_task(safe {fiber.async_task}) : nil
			backtrace = safe {fiber.backtrace}
			
			$stderr.puts "  fiber[#{index}] object_id=#{fiber.object_id} current=#{current} alive=#{alive.inspect} blocking=#{blocking.inspect} async_task=#{async_task.inspect}"
			
			if backtrace.is_a?(Array) && !backtrace.empty?
				backtrace.first(backtrace_limit).each do |frame|
					$stderr.puts "    #{frame}"
				end
			else
				$stderr.puts "    backtrace=#{backtrace.inspect}"
			end
		end
	end
	
	def self.describe_task(task)
		return nil unless task
		return task if task.is_a?(String)
		
		status = task.respond_to?(:status) ? safe {task.status} : nil
		parent = task.respond_to?(:parent) ? safe {task.parent&.object_id} : nil
		
		"#{task.class}(object_id=#{task.object_id}, status=#{status.inspect}, parent=#{parent.inspect})"
	end
	
	def self.dump_ios
		ios = []
		ObjectSpace.each_object(IO) do |io|
			ios << io
		end
		
		open_ios, closed_ios = ios.partition do |io|
			safe {io.closed?} == false
		end
		
		$stderr.puts "ObjectSpace.each_object(IO) count=#{ios.size} open=#{open_ios.size} closed=#{closed_ios.size}"
		
		ios_to_dump = open_ios
		ios_to_dump = ios if ENV["VERBOSE_CLOSED_IOS"]
		
		ios_to_dump.sort_by(&:object_id).each_with_index do |io, index|
			closed = safe {io.closed?}
			fileno = safe {io.fileno}
			tty = safe {io.tty?}
			inspect = safe {io.inspect}
			
			$stderr.puts "  io[#{index}] object_id=#{io.object_id} class=#{io.class} closed=#{closed.inspect} fileno=#{fileno.inspect} tty=#{tty.inspect} inspect=#{inspect.inspect}"
		end
	end
	
	def self.dump_file_descriptors
		entries = Dir.glob("/proc/self/fd/*").sort_by {|path| path[/\d+\z/].to_i}
		
		$stderr.puts "File descriptors count=#{entries.size}"
		
		entries.each do |path|
			target = safe {File.readlink(path)}
			$stderr.puts "  fd[#{File.basename(path)}]=#{target.inspect}"
		end
	rescue => error
		$stderr.puts "File descriptors unavailable: #{error.class}: #{error.message}"
	end
	
	def self.safe
		yield
	rescue => error
		"#{error.class}: #{error.message}"
	end
end
