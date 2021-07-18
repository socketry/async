A synchronization primative, which allows fibers to wait until a particular condition is (edge) triggered. Zero or more fibers can wait on a condition. When the condition is signalled, the fibers will be resumed in order.

## Example

~~~ruby
require 'async'

condition = Async::Condition.new

Sync do
	Async do
		Console.logger.info "Waiting for condition..."
		value = condition.wait
		Console.logger.info "Condition was signalled: #{value}"
	end
	
	Async do |task|
		task.sleep(1)
		Console.logger.info "Signalling condition..."
		condition.signal("Hello World")
	end
end
~~~

### Output

~~~
0.0s     info: Waiting for condition... [ec=0x3c] [pid=47943]
1.0s     info: Signalling condition... [ec=0x64] [pid=47943]
1.0s     info: Condition was signalled: Hello World [ec=0x3c] [pid=47943]
~~~

