#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023, by Samuel Williams.

require 'console'

while true
	pid = Process.spawn("./child.rb")
	Console.info("Spawned child.", pid: pid)
	sleep 2
	Console.info("Sending HUP to child.", pid: pid)
	Process.kill(:HUP, pid)
	status = Process.waitpid(pid)
	Console.info("Child exited.", pid: pid, status: status)
end
