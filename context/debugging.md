# Debugging

This guide explains how to debug issues with programs that use Async.

## Debugging Techniques

### Debugging with `puts`

The simplest way to debug an Async program is to use `puts` to print messages to the console. This is useful for understanding the flow of your program and the values of variables. However, it can be difficult to use `puts` to debug programs that use asynchronous code, as the output may be interleaved. To prevent this, wrap it in `Fiber.blocking{}`:

```ruby
require 'async'

Async do
	3.times do |i|
		sleep i
		Fiber.blocking{puts "Slept for #{i} seconds."}
	end
end
```

Using `Fiber.blocking{}` prevents any context switching until the block is complete, ensuring that the output is not interleaved and that flow control is strictly sequential. You should not use `Fiber.blocking{}` in production code, as it will block the reactor.

### Debugging with IRB

You can use IRB to debug your Async program. In some cases, you will want to stop the world and inspect the state of your program. You can do this by wrapping `binding.irb` inside a `Fiber.blocking{}` block:

```ruby
Async do
	3.times do |i|
		sleep i
		# The event loop will stop at this point and you can inspect the state of your program.
		Fiber.blocking{binding.irb}
	end
end
```

If you don't use `Fiber.blocking{}`, the event loop will continue to run and you will end up with three instances of `binding.irb` running.

### Debugging with `Async::Debug`

The `async-debug` gem provides a visual debugger for Async programs. It is a powerful tool that allows you to inspect the state of your program and see the hierarchy of your program:

```ruby
require 'async'
require 'async/debug'

Sync do
	debugger = Async::Debug.serve
	
	3.times do
		Async do |task|
			while true
				duration = rand
				task.annotate("Sleeping for #{duration} second...")
				sleep(duration)
			end
		end
	end
end
```

When you run this program, it will start a web server on `http://localhost:9000`. You can open this URL in your browser to see the state of your program.
