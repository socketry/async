# Getting Started

This guide shows how to add async to your project and run code asynchronously.

Async is a Ruby library that provides asynchronous programming capabilities using fibers and a fiber scheduler. It allows you to write non-blocking, concurrent code that's easy to understand and maintain.

## Installation

Add the gem to your project:

~~~ bash
$ bundle add async
~~~

## Core Concepts

`async` has several core concepts:

- A {ruby Async::Task} instance which captures your sequential computations.
- A {ruby Async::Reactor} instance which implements the fiber scheduler interface and event loop.
- A {ruby Fiber} is an object which executes user code with cooperative concurrency, i.e. you can transfer execution from one fiber to another and back again.

### What is a scheduler?

A scheduler is an interface which manages the execution of fibers. It is responsible for intercepting blocking operations and redirecting them to an event loop.

### What is an event loop?

An event loop is part of the implementation of a scheduler which is responsible for waiting for events to occur, and waking up fibers when they are ready to run.

### What is a selector?

A selector is part of the implementation of an event loop which is responsible for interacting with the operating system and waiting for specific events to occur. This is often referred to as "select"ing ready events from a set of file descriptors, but in practice has expanded to encompass a wide range of blocking operations.

### What is a reactor?

A reactor is a specific implementation of the scheduler interface, which includes an event loop and selector, and is responsible for managing the execution of fibers.

## Creating an Asynchronous Task

The main entry point for creating tasks is the {ruby Kernel#Async} method. Because this method is defined on `Kernel`, it's available in all parts of your program.

~~~ ruby
require 'async'

Async do |task|
	puts "Hello World!"
end
~~~

A {ruby Async::Task} runs using a {ruby Fiber} and blocking operations e.g. `sleep`, `read`, `write` yield control until the operation can complete. When a blocking operation yields control, it means another fiber can execute, giving the illusion of simultaneous execution.

### When should I use `Async`?

You should use `Async` when you desire explicit concurrency in your program. That means you want to run multiple tasks at the same time, and you want to be able to wait for the results of those tasks.

- You should use `Async` when you want to perform network operations concurrently, such as HTTP requests or database queries.
- You should use `Async` when you want to process independent requests concurrently, such as a web server.
- You should use `Async` when you want to handle multiple connections concurrently, such as a chat server.

You should consider the boundary around your program and the request handling. For example, one task per operation, request or connection, is usually appropriate.

### Waiting for Results

Similar to a promise, {ruby Async::Task} produces results. In order to wait for these results, you must invoke {ruby Async::Task#wait}:

``` ruby
require 'async'

task = Async do
	rand
end

puts "The number was: #{task.wait}"
```

## Creating a Fiber Scheduler

The first (top level) async block will also create an instance of {ruby Async::Reactor} which is a subclass of {ruby Async::Scheduler} to handle the event loop. You can also do this directly using {ruby Fiber.set_scheduler}:

~~~ ruby
require 'async/scheduler'

scheduler = Async::Scheduler.new
Fiber.set_scheduler(scheduler)

Fiber.schedule do
	1.upto(3) do |i|
		Fiber.schedule do
			sleep 1
			puts "Hello World"
		end
	end
end
~~~

## Synchronous Execution in an existing Fiber Scheduler

Unless you need fan-out, map-reduce style concurrency, you can actually use a slightly more efficient {ruby Kernel::Sync} execution model. This method will run your block in the current event loop if one exists, or create an event loop if not. You can use it for code which uses asynchronous primitives, but itself does not need to be asynchronous with respect to other tasks.

```ruby
require 'async/http/internet'

def fetch(url)
	Sync do
		internet = Async::HTTP::Internet.new
		return internet.get(url).read
	end
end

# At the level of your program, this method will create an event loop:
fetch(...)

Sync do
	# The event loop already exists, and will be reused:
	fetch(...)
end
```

In other words, `Sync{...}` is very similar in behaviour to `Async{...}.wait`, but significantly more efficient.

## Enforcing Embedded Execution

In some methods, you may want to implement a fan-out or map-reduce. That requires a parent scheduler. There are two ways you can do this:

```ruby
def fetch_all(urls, parent: Async::Task.current)
	urls.map do |url|
		parent.async do
			fetch(url)
		end
	end.map(&:wait)
end
```

or:

```ruby
def fetch_all(urls)
	Sync do |parent|
		urls.map do |url|
			parent.async do
				fetch(url)
			end
		end.map(&:wait)
	end
end
```

The former allows you to inject the parent, which could be a barrier or semaphore, while the latter will create a new parent scheduler if one does not exist. In both cases, you guarantee that the map operation will be executed in the parent task (of some sort).

## Compatibility

The Fiber Scheduler interface is compatible with most pure Ruby code and well-behaved C code. For example, you can use {ruby Net::HTTP} for performing concurrent HTTP requests:

```ruby
urls = [...]

Async do
	# Perform several concurrent requests:
	responses = urls.map do |url|
		Async do
			Net::HTTP.get(url)
		end
	end.map(&:wait)
end
```

Unfortunately, some libraries do not integrate well with the fiber scheduler: either they are blocking, processor bound, or use thread locals for execution state. To use these libraries, you may be able to use a background thread.

```ruby
Async do
	result = Thread.new do
		# Code which is otherwise unsafe...
	end.value # Wait for the result of the thread, internally non-blocking.
end
```
