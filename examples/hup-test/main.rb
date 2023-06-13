#!/usr/bin/env ruby

require 'console'

while true
	pid = Process.spawn("./child.rb")
	Console.logger.info("Spawned child.", pid: pid)
	sleep 2
	Console.logger.info("Sending HUP to child.", pid: pid)
	Process.kill(:HUP, pid)
	status = Process.waitpid(pid)
	Console.logger.info("Child exited.", pid: pid, status: status)
end
