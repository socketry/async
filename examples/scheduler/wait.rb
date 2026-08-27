#!/usr/bin/env ruby

require_relative '../../lib/async'

Async do
	10.times do
		Async do
			pid = Process.spawn("echo Sleeping; sleep 1; echo Hello World")
			Process.wait(pid)
		end
	end
end
