# Releases

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
