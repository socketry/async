# Getting Started

This guide gives shows how to add async to your project and run code asynchronously.

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

## Creating an Asynchronous Tasks

The main entry point for creating tasks is the {ruby Kernel#Async} method. Because this method is defined on `Kernel`, it's available in all parts of your program.

~~~ ruby
require 'async'

Async do |task|
	puts "Hello World!"
end
~~~

An {ruby Async::Task} runs using a {ruby Fiber} and blocking operations e.g. `sleep`, `read`, `write` yield control until the operation can complete. When a blocking operation yields control, it means another fiber can execute, giving the illusion of simultaneous execution.

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
	3.times do |i|
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

In other words, `Sync{...}` is very similar in behaviour to `Async{...}.wait`.

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

Unfortunately, some libraries do not integrate well with the fiber scheduler, either they are blocking, processor bound, use thread locals for execution state. To uses these libraries, you may be able to use a background thread.

```ruby
Async do
	result = Thread.new do
		# Code which is otherwise unsafe...
	end.value # Wait for the result of the thread, internally non-blocking.
end
```
