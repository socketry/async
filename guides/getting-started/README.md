# Getting Started

This guide explains how to use `async` for event-driven systems.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add async
~~~

## Core Concepts

`async` has several core concepts:

- A {ruby Async::Task} instance which captures your sequential computations.
- A {ruby Async::Reactor} instance which implements the core event loop.

## Creating Tasks

The main entry point for creating tasks is the {ruby Kernel#Async} method. Because this method is defined on `Kernel`, it's available in all areas of your program.

~~~ ruby
require 'async'

Async do |task|
	puts "Hello World!"
end
~~~

An {ruby Async::Task} runs using a {ruby Fiber} and blocking operations e.g. `sleep`, `read`, `write` yield control until the operation can complete.

At the top level, `Async do ... end` will create an event loop, and nested `Async` blocks will reuse the existing event loop. This allows the caller to have either blocking or non-blocking behaviour.

~~~ ruby
require 'async'

def sleepy(duration = 1)
	Async do |task|
		task.sleep duration
		puts "I'm done sleeping, time for action!"
	end
end

# Synchronous operation:
sleepy

# Asynchronous operation:
Async do
	# These two functions will sleep simultaneously.
	sleepy
	sleepy
end
~~~

If you want to guarantee synchronous execution, you can use {ruby Kernel#Sync} which is semantically identical to `Async` except that in all cases it will wait until the given block completes execution.

### Nested Tasks

Sometimes it's convenient to explicitly nest tasks. There are a variety of reasons to do this, including grouping tasks in order to wait for completion. In the most basic case, you can make a child task using the {ruby Async::Task#async} method.

~~~ ruby
require 'async'

def nested_sleepy(task: Async::Task.current)
	# Block caller
	task.sleep 0.1
	
	# Schedule nested task:
	subtask = task.async(annotation: "Sleeping") do |subtask|
		puts "I'm going to sleep..."
		subtask.sleep 1.0
	ensure
		puts "I'm waking up!"
	end
end

Async(annotation: "Top Level") do |task|
	subtask = nested_sleepy(task: task)
	
	task.reactor.print_hierarchy
	#<Async::Reactor:0x64 1 children (running)>
				#<Async::Task:0x78 Top Level (running)>
								#<Async::Task:0x8c Sleeping (running)>
end
~~~

This example creates a child `subtask` from the given parent `task`. It's the most efficient way to schedule a task. The task is executed until the first blocking operation, at which point it will yield control and `#async` will return. The result of this method is the task itself.

## Waiting For Results

Like promises, {ruby Async::Task} produces results. In order to wait for these results, you must invoke {ruby Async::Task#wait}:

~~~ ruby
require 'async'

task = Async do
	rand
end

puts task.wait
~~~

### Waiting For Multiple Tasks

You can use {ruby Async::Barrier#async} to create multiple child tasks, and wait for them all to complete using {ruby Async::Barrier#wait}.

{ruby Async::Barrier} and {ruby Async::Semaphore} are designed to be compatible with each other, and with other tasks that nest `#async` invocations. There are other similar situations where you may want to pass in a parent task, e.g. {ruby Async::IO::Endpoint#bind}.

~~~ ruby
barrier = Async::Barrier.new
semaphore = Async::Semaphore.new(2)

semaphore.async(parent: barrier) do
	# ...
end
~~~

A `parent:` in this context is anything that responds to `#async` in the same way that {ruby Async::Task} responds to `#async`. In situations where you strictly depend on the interface of {ruby Async::Task}, use the `task: Task.current` pattern.

### Stopping Tasks

Use {ruby Async::Task#stop} to stop tasks. This function raises {ruby Async::Stop} on the target task and all descendent tasks.

~~~ ruby
require 'async'

Async do
	sleepy = Async do |task|
		task.sleep 1000
	end
	
	sleepy.stop
end
~~~

When you design a server, you should return the task back to the caller. They can use this task to stop the server if needed, independently of any other unrelated tasks within the reactor, and it will correctly clean up all related tasks.

## Resource Management

In order to ensure your resources are cleaned up correctly, make sure you wrap resources appropriately, e.g.:

~~~ ruby
Async::Reactor.run do
	begin
		socket = connect(remote_address) # May raise Async::Stop

		socket.write(...) # May raise Async::Stop
		socket.read(...) # May raise Async::Stop
	ensure
		socket.close if socket
	end
end
~~~

As tasks run synchronously until they yield back to the reactor, you can guarantee this model works correctly. While in theory `IO#autoclose` allows you to automatically close file descriptors when they go out of scope via the GC, it may produce unpredictable behavour (exhaustion of file descriptors, flushing data at odd times), so it's not recommended.

## Exception Handling

{ruby Async::Task} captures and logs exceptions. All unhandled exceptions will cause the enclosing task to enter the `:failed` state. Non-`StandardError` exceptions are re-raised immediately and will generally cause the reactor to fail. This ensures that exceptions will always be visible and cause the program to fail appropriately.

~~~ ruby
require 'async'

task = Async do
	# Exception will be logged and task will be failed.
	raise "Boom"
end

puts task.status # failed
puts task.result # raises RuntimeError: Boom
~~~

### Propagating Exceptions

If a task has finished due to an exception, calling `Task#wait` will re-raise the exception.

~~~ ruby
require 'async'

Async do
	task = Async do
		raise "Boom"
	end
	
	begin
		task.wait # Re-raises above exception.
	rescue
		puts "It went #{$!}!"
	end
end
~~~

You can also specify that all unhandled exceptions including `StandardError` be raised immediately using the `:propagate_errors` option. If this option is set in a subtask it will apply to the parent task.

~~~ruby
require 'async'

Async do |task|
	task.async(raise_errors: true) do
		raise "Boom"
	end
end

# raises RuntimeError: Boom
~~~

## Timeouts

You can wrap asynchronous operations in a timeout. This ensures that malicious services don't cause your code to block indefinitely.

~~~ ruby
require 'async'

Async do |task|
	task.with_timeout(1) do
		task.sleep 100
	rescue Async::TimeoutError
		puts "I timed out!"
	end
end
~~~

### Reoccurring Timers

Sometimes you need to do some periodic work in a loop.

~~~ ruby
require 'async'

Async do |task|
	while true
		puts Time.now
		task.sleep 1
	end
end
~~~
