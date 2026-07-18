#!/usr/bin/env ruby

require_relative '../../lib/async'

Async do
	Async do |task|
		task.sleep(1)
		Async.logger.info(task) {"Finished sleeping."}
	end
	
	# When all other non-transient tasks are finished, the transient task will be stopped too.
	Async(transient: true) do |task|
		while true
			Async.logger.info(task) {"Transient task sleeping..."}
			task.reactor.print_hierarchy
			task.sleep(2)
		end
	ensure
		Async.logger.info(task) {"Transient task exiting: #{$!}"}
	end
end

