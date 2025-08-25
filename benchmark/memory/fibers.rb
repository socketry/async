#!/usr/bin/env ruby

pid = fork do
	fibers = 100.times.map do
		Fiber.new{loop{Fiber.yield}}.resume
	end
	
	sleep
end

sleep 1

require 'process/metrics'
metrics = Process::Metrics::General.capture(pid: pid)

pp metrics

Process.kill(:TERM, pid)
