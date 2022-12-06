A synchronization primitive, which allows one task to wait for a number of other tasks to complete. It can be used in conjunction with {Semaphore}.

## Example

~~~ ruby
require 'async'
require 'async/barrier'

Sync do
	Console.logger.info("Barrier Example: sleep sort.")
	barrier = Async::Barrier.new
	
	# Generate an array of 10 numbers:
	numbers = 10.times.map{rand(10)}
	sorted = []
	
	# Sleep sort the numbers:
	numbers.each do |number|
		barrier.async do |task|
			task.sleep(number)
			sorted << number
		end
	end
	
	# Wait for all the numbers to be sorted:
	barrier.wait
	
	Console.logger.info("Sorted", sorted)
end
~~~

### Output

~~~
0.0s     info: Barrier Example: sleep sort.
9.0s     info: Sorted
             | [3, 3, 3, 4, 4, 5, 5, 5, 8, 9]
~~~
