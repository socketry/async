A synchronization primitive, which allows you to wait for tasks to complete in order of completion. This is useful for implementing a task pool, where you want to wait for the first task to complete, and then cancel the rest.

If you try to wait for more things than you have added, you will deadlock.

## Example

~~~ ruby
require 'async'
require 'async/semaphore'
require 'async/barrier'
require 'async/waiter'

Sync do
	barrier = Async::Barrier.new
	waiter = Async::Waiter.new(parent: barrier)
	semaphore = Async::Semaphore.new(2, parent: waiter)
	
	# Sleep sort the numbers:
	generator = Async do
		while true
			semaphore.async do |task|
				number = rand(1..10)
				sleep(number)
			end
		end
	end
	
	numbers = []
	
	4.times do
		# Wait for all the numbers to be sorted:
		numbers << waiter.wait
	end
	
	# Don't generate any more numbers:
	generator.stop
	
	# Stop all tasks which we don't care about:
	barrier.stop
	
	Console.info("Smallest", numbers)
end
~~~

### Output

~~~
0.0s     info: Smallest
             | [3, 3, 1, 2]
~~~
