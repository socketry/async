#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative "../../lib/async"
require_relative "../../lib/async/idler"

Async do
	idler = Async::Idler.new(0.8)
	
	Async do
		while true
			idler.async do
				$stdout.write "."
				while true
					sleep 0.1
				end
			end
		end
	end
	
	scheduler = Fiber.scheduler
	while true
		load = scheduler.load
		
		$stdout.write "\nLoad: #{load} "
		sleep 1.0
	end
end
