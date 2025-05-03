# Releases

## v2.24.0

  - Ruby v3.1 support is dropped.
  - `Async::Wrapper` which was previously deprecated, is now removed.

### Flexible Timeouts

When {ruby Async::Scheduler\#with\_timeout} is invoked with a block, it can receive a {ruby Async::Timeout} instance. This allows you to adjust or cancel the timeout while the block is executing. This is useful for long-running tasks that may need to adjust their timeout based on external factors.

``` ruby
Async do
	Async::Scheduler.with_timeout(5) do |timeout|
		# Do some work that may take a while...
		
		if some_condition
			timeout.cancel! # Cancel the timeout
		else
			# Add 10 seconds to the current timeout:
			timeout.adjust(10)
			
			# Reduce the timeout by 10 seconds:
			timeout.adjust(-10)
			
			# Set the timeout to 10 seconds from now:
			timeout.duration = 10
			
			# Increase the current duration:
			timeout.duration += 10
		end
	end
end
```

## v2.23.0

  - Rename `ASYNC_SCHEDULER_DEFAULT_WORKER_POOL` to `ASYNC_SCHEDULER_WORKER_POOL`.

### Fiber Stall Profiler

After several iterations of experimentation, we are officially introducing the fiber stall profiler, implemented using the optional `fiber-profiler` gem. This gem is not included by default, but can be added to your project:

``` bash
$ bundle add fiber-profiler
```

After adding the gem, you can enable the fiber stall profiler by setting the `FIBER_PROFILER_CAPTURE=true` environment variable:

``` bash
$ FIBER_PROFILER_CAPTURE=true bundle exec ruby -rasync -e 'Async{Fiber.blocking{sleep 0.1}}'
Fiber stalled for 0.105 seconds
-e:1 in c-call '#<Class:Fiber>#blocking' (0.105s)
	-e:1 in c-call 'Kernel#sleep' (0.105s)
Skipped 1 calls that were too short to be meaningful.
```

The fiber profiler will help you find problems with your code that cause the event loop to stall, which can be a common source of performance issues in asynchronous code.

## v2.21.1

### Worker Pool

Ruby 3.4 will feature a new fiber scheduler hook, `blocking_operation_wait` which allows the scheduler to redirect the work given to `rb_nogvl` to a worker pool.

The Async scheduler optionally supports this feature using a worker pool, by using the following environment variable:

    ASYNC_SCHEDULER_WORKER_POOL=true

This will cause the scheduler to use a worker pool for general blocking operations, rather than blocking the event loop.

It should be noted that this isn't a net win, as the overhead of using a worker pool can be significant compared to the `rb_nogvl` work. As such, it is recommended to benchmark your application with and without the worker pool to determine if it is beneficial.

## v2.20.0

### Traces and Metrics Providers

Async now has [traces](https://github.com/socketry/traces) and [metrics](https://github.com/socketry/metrics) providers for various core classes. This allows you to emit traces and metrics to a suitable backend (including DataDog, New Relic, OpenTelemetry, etc.) for monitoring and debugging purposes.

To take advantage of this feature, you will need to introduce your own `config/traces.rb` and `config/metrics.rb`. Async's own repository includes these files for testing purposes, you could copy them into your own project and modify them as needed.

## v2.19.0

### Async::Scheduler Debugging

Occasionally on issues, I encounter people asking for help and I need more information. Pressing Ctrl-C to exit a hung program is common, but it usually doesn't provide enough information to diagnose the problem. Setting the `CONSOLE_LEVEL=debug` environment variable will now print additional information about the scheduler when you interrupt it, including a backtrace of the current tasks.

    > CONSOLE_LEVEL=debug bundle exec ruby ./test.rb
    ^C  0.0s    debug: Async::Reactor [oid=0x974] [ec=0x988] [pid=9116] [2024-11-08 14:12:03 +1300]
                   | Scheduler interrupted: Interrupt
                   | #<Async::Reactor:0x0000000000000974 1 children (running)>
                   | 	#<Async::Task:0x000000000000099c /Users/samuel/Developer/socketry/async/lib/async/scheduler.rb:185:in `transfer' (running)>
                   | 	→ /Users/samuel/Developer/socketry/async/lib/async/scheduler.rb:185:in `transfer'
                   | 	  /Users/samuel/Developer/socketry/async/lib/async/scheduler.rb:185:in `block'
                   | 	  /Users/samuel/Developer/socketry/async/lib/async/scheduler.rb:207:in `kernel_sleep'
                   | 	  /Users/samuel/Developer/socketry/async/test.rb:7:in `sleep'
                   | 	  /Users/samuel/Developer/socketry/async/test.rb:7:in `sleepy'
                   | 	  /Users/samuel/Developer/socketry/async/test.rb:12:in `block in <top (required)>'
                   | 	  /Users/samuel/Developer/socketry/async/lib/async/task.rb:197:in `block in run'
                   | 	  /Users/samuel/Developer/socketry/async/lib/async/task.rb:420:in `block in schedule'
    /Users/samuel/Developer/socketry/async/lib/async/scheduler.rb:317:in `select': Interrupt
    ... (backtrace continues) ...

This gives better visibility into what the scheduler is doing, and should help diagnose issues.

### Console Shims

The `async` gem depends on `console` gem, because my goal was to have good logging by default without thinking about it too much. However, some users prefer to avoid using the `console` gem for logging, so I've added an experimental set of shims which should allow you to bypass the `console` gem entirely.

``` ruby
require 'async/console'
require 'async'

Async{raise "Boom"}
```

Will now use `Kernel#warn` to print the task failure warning:

    #<Async::Task:0x00000000000012d4 /home/samuel/Developer/socketry/async/lib/async/task.rb:104:in `backtrace' (running)>
    Task may have ended with unhandled exception.
    (irb):4:in `block in <top (required)>': Boom (RuntimeError)
    	from /home/samuel/Developer/socketry/async/lib/async/task.rb:197:in `block in run'
    	from /home/samuel/Developer/socketry/async/lib/async/task.rb:420:in `block in schedule'

## v2.18.0

  - Add support for `Sync(annotation:)`, so that you can annotate the block with a description of what it does, even if it doesn't create a new task.

## v2.17.0

  - Introduce `Async::Queue#push` and `Async::Queue#pop` for compatibility with `::Queue`.

## v2.16.0

### Better Handling of Async and Sync in Nested Fibers

Interleaving bare fibers within `Async` and `Sync` blocks should not cause problems, but it presents a number of issues in the current implementation. Tracking the parent-child relationship between tasks, when they are interleaved with bare fibers, is difficult. The current implementation assumes that if there is no parent task, then it should create a new reactor. This is not always the case, as the parent task might not be visible due to nested Fibers. As a result, `Async` will create a new reactor, trying to stop the existing one, causing major internal consistency issues.

I encountered this issue when trying to use `Async` within a streaming response in Rails. The `protocol-rack` [uses a normal fiber to wrap streaming responses](https://github.com/socketry/protocol-rack/blob/cb1ca44e9deadb9369bdb2ea03416556aa927c5c/lib/protocol/rack/body/streaming.rb#L24-L28), and if you try to use `Async` within it, it will create a new reactor, causing the server to lock up.

Ideally, `Async` and `Sync` helpers should work when any `Fiber.scheduler` is defined. Right now, it's unrealistic to expect `Async::Task` to work in any scheduler, but at the very least, the following should work:

``` ruby
reactor = Async::Reactor.new # internally calls Fiber.set_scheduler

# This should run in the above reactor, rather than creating a new one.
Async do
  puts "Hello World"
end
```

In order to do this, bare `Async` and `Sync` blocks should use `Fiber.scheduler` as a parent if possible.

See <https://github.com/socketry/async/pull/340> for more details.
