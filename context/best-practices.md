# Best Practices

This guide gives an overview of best practices for using Async.

## Use a top-level `Sync` to denote the root of your program

`Async{}` has two uses: it creates an event loop if one doesn't exist, and it creates a task which runs asynchronously with respect to the parent scope. However, the top level `Async{}` block will be synchronous because it creates the event loop. In some programs, you do not care about executing asynchronously, but you still want your code to run in an event loop. `Sync{}` exists to do this efficiently.

```ruby
require 'async'

class Packages
	def initialize(urls)
		@urls = urls
	end
	
	def fetch
		# A common use case is to make functions which appear synchronous, but internally use asynchronous execution:
		Sync do |task|
			@urls.map do |url|
				task.async do
					fetch(url)
				end
			end.map(&:wait)
		end
	end
end
```

`Sync{...}` is semantically equivalent to `Async{}.wait`, but it is more efficient. It is the preferred way to run code in an event loop at the top level of your program or to ensure some code runs in an event loop without creating a new task. The name `Sync` means "Synchronous Async", indicating that it runs synchronously with respect to the outer scope, but still allows for asynchronous execution within it.

### Current Task

In some scenarios, it can be invalid to call a method outside of an event loop, for example a top level `Async{...}` can block forever, which might be unexpected.

```ruby
def wait(queue)
	Async do
		queue.pop
	end
end
```

You can force callers of a method to only call the method within an asynchronous context by using a keyword argument `parent: Async::Task.current`. If no task is present, this will raise an exception.

```ruby
def wait(queue, parent: Async::Task.current)
	parent.async do
		queue.pop
	end
end
```

This expresses the intent to the caller that this method should only be invoked from within an asynchonous task. In addition, it allows the caller to substitute other parent objects, like semaphores or barriers, which can be useful for managing concurrency.

## Use barriers to manage unbounded concurrency

Barriers provide a way to manage an unbounded number of tasks.

```ruby
Async do
	barrier = Async::Barrier.new
	
	items.each do |item|
		barrier.async do
			process(item)
		end
	end
	
	# Process the tasks in order of completion:
	barrier.wait do |task|
		result = task.wait
		# Do something with result.

		# If you don't want to wait for any more tasks you can break:
		break
	end
	
	# Or just wait for all tasks to finish:
	barrier.wait # May raise an exception if a task failed.
ensure
	# Stop all outstanding tasks in the barrier:
	barrier&.stop
end
```

## Use a semaphore to limit the number of concurrent tasks

Semaphores allow you to limit the level of concurrency to a fixed number of tasks:

```ruby
Async do |task|
	barrier = Async::Barrier.new
	semaphore = Async::Semaphore.new(4, parent: barrier)
	
	# Since the semaphore.async may block, we need to run the work scheduling in a child task:
	task.async do
		items.each do |item|
			semaphore.async do
				process(item)
			end
		end
	end
	
	# Wait for all the work to complete:
	barrier.wait
ensure
	# Stop all outstanding tasks in the barrier:
	barrier&.stop
end
```

In general, the barrier should be the root of your task hierarchy, and the semaphore should be a child of the barrier. This allows you to manage the lifetime of all tasks created by the semaphore, and ensures that all tasks are stopped when the barrier is stopped.

### Idler

Idlers are like semaphores but with a limit defined by current processor utilization. In other words, an idler will do work up to a specific ratio of idle/busy time in the scheduler, and try to maintain that.

```ruby
Async do
	# Create an idler that will aim for a load average of 80%:
	idler = Async::Idler.new(0.8)
	
	# Some list of work to be done:
	work.each do |work|
		idler.async do
			# Do the work:
			work.call
		end
	end
end
```

The idler will try to schedule as much work such that the load of the scheduler stays at around 80% saturation.

## Use queues to share data between tasks

Queues allow you to share data between tasks without the risk of data corruption or deadlocks.

```ruby
Async do |task|
	queue = Async::Queue.new
	
	reader = task.async do
		while chunk = socket.gets
			queue.push(chunk)
		end
	end
		# After this point, we won't be able to add items to the queue, and popping items will eventually result in nil once all items are dequeued:
		queue.close
	end
	
	# Process items from the queue:
	while line = queue.pop
		process(line)
	end
end
```

The above program may have unbounded memory use, so it can be a good idea to use a limited queue with back-pressure:

```ruby
Async do |task|
	queue = Async::LimitedQueue.new(8)
	
	# Everything else is the same from the queue example, except that the pushing onto the queue will block once 8 items are buffered.
end
```

## Use timeouts for operations that might block forever

General timeouts can be imposed by using `task.with_timeout(duration)`.

```ruby
Async do |task|
	# This will raise an Async::TimeoutError after 1 second:
	task.with_timeout(1) do |timeout|
		# Timeout#duration= can be used to adjust the duration of the timeout.
		# Timeout#cancel can be used to cancel the timeout completely.
		
		sleep 10
	end
end
```

It can be especially important to impose timeouts when processing user-provided data.

## 