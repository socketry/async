#!/usr/bin/env ruby

require 'irb'
require 'console'

pids = ARGV.collect(&:to_i)

TICKS = Process.clock_getres(:TIMES_BASED_CLOCK_PROCESS_CPUTIME_ID, :hertz).to_f

def getrusage(pid)
	fields = File.read("/proc/#{pid}/stat").split(/\s+/)
	
	return Process::Tms.new(
		fields[14].to_f / TICKS,
		fields[15].to_f / TICKS,
		fields[16].to_f / TICKS,
		fields[17].to_f / TICKS,
	)
end

def parse(value)
	case value
	when /^\s*\d+\.\d+/
		Float(value)
	when /^\s*\d+/
		Integer(value)
	else
		value = value.strip
		if value.empty?
			nil
		else
			value
		end
	end
end

def strace(pid, duration = 60)
	input, output = IO.pipe
	
	pid = Process.spawn("strace", "-p", pid.to_s, "-cqf", "-w", "-e", "!futex", err: output)
	
	output.close
	
	Signal.trap(:INT) do
		Process.kill(:INT, pid)
		Signal.trap(:INT, :DEFAULT)
	end
	
	Thread.new do
		sleep duration
		Process.kill(:INT, pid)
	end
	
	summary = {}
	
	if first_line = input.gets
		if rule = input.gets # horizontal separator
			pattern = Regexp.new(
				rule.split(/\s/).map{|s| "(.{1,#{s.size}})"}.join(' ')
			)
			
			header = pattern.match(first_line).captures.map{|key| key.strip.to_sym}
		end
		
		while line = input.gets
			break if line == rule
			row = pattern.match(line).captures.map{|value| parse(value)}
			fields = header.zip(row).to_h
			
			summary[fields[:syscall]] = fields
		end
		
		if line = input.gets
			row = pattern.match(line).captures.map{|value| parse(value)}
			fields = header.zip(row).to_h
			summary[:total] = fields
		end
	end
	
	_, status = Process.waitpid2(pid)
	
	Console.logger.error(status) do |buffer|
		buffer.puts first_line
	end unless status.success?
	
	return summary
end

pids.each do |pid|
	start_times = getrusage(pid)
	Console.logger.info("Process #{pid} start times:", start_times)
	
	# sleep 60
	summary = strace(pid)
	
	Console.logger.info("strace -p #{pid}") do |buffer|
		summary.each do |fields|
			buffer.puts fields.inspect
		end
	end
	
	end_times = getrusage(pid)
	Console.logger.info("Process #{pid} end times:", end_times)
	
	if total = summary[:total]
		process_duration = end_times.utime - start_times.utime
		wait_duration = summary[:total][:seconds]
	
		Console.logger.info("Process Waiting: #{wait_duration.round(4)}s out of #{process_duration.round(4)}s") do |buffer|
			buffer.puts "Wait percentage: #{(wait_duration / process_duration * 100.0).round(2)}%"
		end
	else
		Console.logger.warn("No system calls detected.")
	end
end
