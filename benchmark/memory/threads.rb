#!/usr/bin/env ruby

pid = fork do
	threads = 100.times.map do
		Thread.new{sleep}
	end
	
	threads.each(&:join)
end

sleep 1

require 'process/metrics'
metrics = Process::Metrics::General.capture(pid: pid)

pp metrics

Process.kill(:TERM, pid)
