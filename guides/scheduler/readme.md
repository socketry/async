# Scheduler

This guide gives an overview of how the scheduler is implemented.

## Overview

The {ruby Async::Scheduler} uses an event loop to execute tasks. When tasks are waiting on blocking operations like IO, the scheduler will use the operating system's native event system to wait for the operation to complete. This allows the scheduler to efficiently handle many tasks.

### Tasks

Tasks are the building blocks of concurrent programs. They are lightweight and can be scheduled by the event loop. Tasks can be nested, and the parent task is used to determine the current reactor. Tasks behave like promises, in the sense you can wait on them to complete, and they might fail with an exception.

~~~ ruby
require 'async'

def sleepy(duration, task: Async::Task.current)
	task.async do |subtask|
		subtask.annotate "I'm going to sleep #{duration}s..."
		sleep duration
		puts "I'm done sleeping!"
	end
end

def nested_sleepy(task: Async::Task.current)
	task.async do |subtask|
		subtask.annotate "Invoking sleepy 5 times..."
		5.times do |index|
			sleepy(index, task: subtask)
		end
	end
end

Async do |task|
	task.annotate "Invoking nested_sleepy..."
	subtask = nested_sleepy
	
	# Print out all running tasks in a tree:
	task.print_hierarchy($stderr)
	
	# Kill the subtask
	subtask.cancel
end
~~~

### Thread Safety

Most methods of the reactor and related tasks are not thread-safe, so you'd typically have [one reactor per thread or process](https://github.com/socketry/async-container).

### Embedding Schedulers

{ruby Async::Scheduler#run} will run until the reactor runs out of work to do. To run a single iteration of the reactor, use {ruby Async::Scheduler#run_once}.

~~~ ruby
require 'async'

Console.logger.debug!
reactor = Async::Scheduler.new

# Run the reactor for 1 second:
reactor.async do |task|
	sleep 1
	puts "Finished!"
end

while reactor.run_once
	# Round and round we go!
end
~~~

You can use this approach to embed the reactor in another event loop. For some integrations, you may want to specify the maximum time to wait to {ruby Async::Scheduler#run_once}.

### Cancelling a Scheduler

{ruby Async::Scheduler#cancel} will cancel the current scheduler and all children tasks.

### Fiber Scheduler Integration

In order to integrate with native Ruby blocking operations, the {ruby Async::Scheduler} uses a {ruby Fiber::Scheduler} interface.

```ruby
require "async"

scheduler = Async::Scheduler.new
Fiber.set_scheduler(scheduler)

Fiber.schedule do
	puts "Hello World!"
end
```

### Worker Pool

Ruby 3.4 introduced the `blocking_operation_wait` fiber scheduler hook, which allows the scheduler to execute blocking operations (e.g. `rb_nogvl`) on a worker pool, rather than blocking the event loop. The worker pool is disabled by default. You can enable it using the `ASYNC_SCHEDULER_WORKER_POOL=true` environment variable, which is read when `async` is loaded, or at runtime using {ruby Async::Scheduler.enable_worker_pool}:

```ruby
require "async"

Async::Scheduler.enable_worker_pool

Sync do
	# Blocking operations are executed by the worker pool.
end
```

The setting applies to schedulers created afterwards without an explicit `worker_pool:` argument, including those created by `Sync`, `Async` and {ruby Async::Reactor}. Each scheduler creates its own worker pool and closes it when the scheduler is closed. To customize the worker pool, set {ruby Async::Scheduler.worker_pool} to a factory which returns a new worker pool for each scheduler, or `nil` to disable it:

```ruby
Async::Scheduler.worker_pool = ->{IO::Event::WorkerPool.new(maximum_worker_count: 4)}
```

An explicit `worker_pool:` argument takes precedence over these settings:

```ruby
scheduler = Async::Scheduler.new(worker_pool: true)
```

The worker pool has overhead, which can be significant compared to the work being offloaded, so you should benchmark your application with and without it.

## Design

### Optimistic vs Pessimistic Scheduling

There are two main strategies for scheduling tasks: optimistic and pessimistic. An optimistic scheduler is usually greedy and will try to execute tasks as soon as they are scheduled using a direct transfer of control flow. A pessimistic scheduler will schedule tasks into the event loop ready list and will only execute them on the next iteration of the event loop.

```ruby
Async do
	puts "Hello "
	
	Async do
		puts "World"
	end
	
	puts "!"
end
```

An optimstic scheduler will print "Hello World!", while a pessimistic scheduler will print "Hello !World". In practice you should not design your code to rely on the order of execution, but it's important to understand the difference. It is an unspecifed implementation detail of the scheduler.
