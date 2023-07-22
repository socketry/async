#!/usr/bin/env ruby

require_relative '../../lib/async'

scheduler = Async::Scheduler.new
Fiber.set_scheduler(scheduler)

Fiber.schedule do
	sleep(1)
	puts "Finished sleeping!"
end

raise "Boom!"
