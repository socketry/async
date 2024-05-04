A synchronization primitive, which allows fibers to wait until a particular condition is (edge) triggered. Zero or more fibers can wait on a condition. When the condition is signalled, the fibers will be resumed in order.

## Example

~~~ ruby
require 'async'

Sync do
	condition = Async::Condition.new
	
	Async do
		Console.info "Waiting for condition..."
		value = condition.wait
		Console.info "Condition was signalled: #{value}"
	end
	
	Async do |task|
		task.sleep(1)
		Console.info "Signalling condition..."
		condition.signal("Hello World")
	end
end
~~~

### Output

~~~
0.0s     info: Waiting for condition...
1.0s     info: Signalling condition...
1.0s     info: Condition was signalled: Hello World
~~~
