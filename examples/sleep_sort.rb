#!/usr/bin/env ruby

require_relative '../lib/async'

def sleep_sort(items)
	Async::Reactor.run do |task|
		# Where to save the sorted items:
		sorted_items = []
		
		items.each do |item|
			# Spawn an async task...
			task.async do |nested_task|
				# Which goes to sleep for the specified duration:
				nested_task.sleep(item)
				
				# And then appends the item to the sorted array:
				sorted_items << item
			end
		end
		
		# Wait for all children to complete.
		task.children.each(&:wait)
		
		# Return the result:
		sorted_items
	end.wait # Wait for the entire process to complete.
end

# Calling at the top level blocks the thread:
puts sleep_sort(5.times.collect{rand}).inspect

# Calling in your own reactor allows you to control the asynchronus behaviour:
Async::Reactor.run do |task|
	3.times do
		task.async do
			puts sleep_sort(5.times.collect{rand}).inspect
		end
	end
end
