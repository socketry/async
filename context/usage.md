# Async Usage

Async is a Ruby library that provides asynchronous programming capabilities using fibers and a fiber scheduler. It allows you to write non-blocking, concurrent code that's easy to understand and maintain.

## Tasks

Async uses tasks to represent units of concurrency. Those tasks are backed by fibers and exist in an execution tree. The main way to create a task is to use `Async{...}`:

``` ruby
Async do
	# Internally non-blocking write:
	puts "Hello World"
end
```

Conceptually, `Async{...}` means execute the given block of code sequentially, but it's execution is asynchronous to the outside world. For example:

``` ruby
Async do |task|
	# Start two tasks that will run asynchronously:
	child1 = Async{sleep 1; puts "Hello"}
	# Using task.async is the same as Async, but is slightly more efficient:
	child2 = task.async{sleep 2; puts "World"}
	
	# Wait for both tasks to complete:
	child1.wait
	child2.wait
end
```

Waiting on a task returns the result of the block:

```ruby
Async do |task|
	# Run some computation:
	child = task.async{computation}
	
	# Get the result of the computation:
	result = child.wait
end
```

### Sync

`Async{}` has two uses: it creates an event loop if one doesn't exist, and it creates a task which runs asynchronously with respect to the parent scope. However, the top level `Async{}` block will be synchronous because it creates the event loop. In some programs, you do not care about executing asynchronously, but you still want your code to run in an event loop. `Sync{}` exists to do this efficiently.

```ruby
# At the top level, this is equivalent to Async{}.wait
Sync do
end

Sync do
	# This is a no-op, as it's already in an event loop:
	Sync{...}
	
	# It's semantically equivalent to:
	Async{...}.wait
	# but it is more efficient.
end
```

The main use case for `Sync` is to embed `Async` in methods, e.g.

```ruby
def fetch_data
	Sync do
		# No matter what, this will happen asynchronously:
		3.times do
			Async{Net::HTTP.get(...)}
		end
	end
end
```

There are two options for the above code - either it's called from within an event loop, in which case `Sync do ... end` directly executes the block, OR it's invoked without an event loop, in which case it creates an event loop, executes the block, and returns the result (or raises the exception).

### Current Task

It is possible to get the current task using `Async::Task.current`. If you call this methoud without a task, it will raise an exception. If you want a method which returns the current task OR nil, use `Async::Task.current?`. Generally speaking you should not use these methods and instead use the task yielded to the `Async{|task| ...}` block. However, there is one scenario where it can be useful:

```ruby
def fetch_data(parent: Async::Task.current)
	3.times do
		Async{Net::HTTP.get(...)}
	end
end
```

If `fetch_data` is called outside of an Async block, it will raise an exception. So, it expresses the intent to the caller that this method should only be invoked from within an asynchonous task.

## Timeouts

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

## Barriers

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

## Semaphores

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

## Queues

Queues allow you to share data between disconnected tasks:

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
