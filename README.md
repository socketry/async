# ![Async](logo.svg)

Async is a composable asynchronous I/O framework for Ruby based on [nio4r] and [timers].

[timers]: https://github.com/socketry/timers
[nio4r]: https://github.com/socketry/nio4r
[![Development Status](https://github.com/socketry/async/workflows/Development/badge.svg)](https://github.com/socketry/async/actions?workflow=Development)

> "Lately I've been looking into `async`, as one of my projects – [tus-ruby-server](https://github.com/janko/tus-ruby-server) – would really benefit from non-blocking I/O. It's really beautifully designed." *– [janko](https://github.com/janko)*

## Motivation

Several years ago, I was hosting websites on a server in my garage. Back then, my ADSL modem was very basic, and I wanted to have a DNS server which would resolve to an internal IP address when the domain itself resolved to my public IP. Thus was born [RubyDNS]. This project [was originally built on](https://github.com/ioquatix/rubydns/tree/v0.8.5) top of [EventMachine], but a lack of support for [IPv6 at the time](https://github.com/ioquatix/rubydns/issues/45) and [other problems](https://github.com/ioquatix/rubydns/issues/14), meant that I started looking for other options. Around that time [Celluloid] was picking up steam. I had not encountered actors before and I wanted to learn more about it. So, [I reimplemented RubyDNS on top of Celluloid](https://github.com/ioquatix/rubydns/tree/v0.9.0) and this eventually became the first stable release.

Moving forward, I refactored the internals of RubyDNS into [Celluloid::DNS]. This rewrite helped solidify the design of RubyDNS and to a certain extent it works. However, [unfixed bugs and design problems](https://github.com/celluloid/celluloid/pull/710) in Celluloid meant that RubyDNS 2.0 was delayed by almost 2 years. I wasn't happy releasing it with known bugs and problems. After working on the issues for a while, and thinking about possible solutions, I decided to build a small event reactor using [nio4r] and [timers], the core parts of [Celluloid::IO] which made it work so well. The result is this project.

One observation I made when looking at existing gems for asynchronous IO was a tendency to try and do everything within a single code-base. The design of this core library is deliberately simple. Additional libraries provide asynchronous networking, process management, etc. It's likely you will prefer to depend on [async-io] for actual wrappers around `IO` and `Socket`. This helps to ensure a clean separation of concerns.

In designing this library, I also built a [similarly designed C++ library of the same name](https://github.com/kurocha/async). These two libraries share similar design principles.

[Celluloid]: https://github.com/celluloid/celluloid
[Celluloid::IO]: https://github.com/celluloid/celluloid-io
[Celluloid::DNS]: https://github.com/celluloid/celluloid-dns
[EventMachine]: https://github.com/eventmachine/eventmachine
[RubyDNS]: https://github.com/ioquatix/rubydns
[async-io]: https://github.com/socketry/async-io
## Installation

Add this line to your application's Gemfile:

``` ruby
gem "async"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install async

## Usage

Please [try the interactive online tutorial](https://katacoda.com/ioquatix/scenarios/async-introduction).

### Tasks

An `Async::Task` runs using a `Fiber` and blocking operations e.g. `sleep`, `read`, `write` yield control until the operation can complete. There are two main methods to create tasks.

#### `Async{...}`

The highest level entry point is `Async{...}`. It's useful if you are building a library and you want well defined asynchronous semantics. This internally invokes `Async::Reactor.run{...}`.

``` ruby
def run_server
	Async do |task|
		# ... acccept connections
	end
end
```

If `Async(&block)` happens within an existing reactor, it will schedule an asynchronous task and return. If `Async(&block)` happens outside of an existing reactor, it will create a reactor, schedule the asynchronous task, and block until it completes. The task is scheduled by calling `Async::Reactor#async(&block)`.

This allows the caller to have either blocking or non-blocking behaviour.

``` ruby
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
```

The cost of using `Async{...}` is minimal for initialization/server setup, but is not ideal for per-connection tasks.

#### `Async::Task#async`

If you can guarantee you are running within a task, and have access to it (e.g. via an argument), you can efficiently schedule new tasks using the `Async::Task#async(&block)` method.

``` ruby
require 'async'

def nested_sleepy(task: Async::Task.current)
	# Block caller
	task.sleep 0.1
	
	# Schedule nested task:
	subtask = task.async do |subtask|
		puts "I'm going to sleep..."
		subtask.sleep 1.0
	ensure
		puts "I'm waking up!"
	end
end

Async do |task|
	subtask = nested_sleepy(task: task)
end
```

This example creates a child `subtask` from the given parent `task`. It's the most efficient way to schedule a task. The task is executed until the first blocking operation, at which point it will yield control and `#async` will return. The result of this method is the task itself.

### Waiting for Results

Like promises, `Async::Task` produces results. In order to wait for these results, you must invoke `Async::Task#wait`:

``` ruby
require 'async'

task = Async do
	rand
end

puts task.wait
```

### Stopping Tasks

Use `Async::Task#stop` to stop tasks. This function raises `Async::Stop` on the target task and all descendent tasks.

``` ruby
require 'async'

Async do
	sleepy = Async do |task|
		task.sleep 1000
	end
	
	sleepy.stop
end
```

When you design a server, you should return the task back to the caller. They can use this task to stop the server if needed, independently of any other unrelated tasks within the reactor, and it will correctly clean up all related tasks.

### Reactors

`Async::Reactor` is the top level IO reactor, and runs multiple tasks asynchronously. The reactor itself is not thread-safe, so you'd typically have [one reactor per thread or process](https://github.com/socketry/async-container).

#### Hierarchy

`Async::Reactor` and `Async::Task` form nodes in a tree. Reactors and tasks can spawn children tasks. When you invoke `Async::Reactor#async`, the parent task is determined by calling `Async::Task.current?` which uses fiber local storage. A slightly more efficient method is to use `Async::Task#async`, which uses `self` as the parent task.

``` ruby
require 'async'

def sleepy(duration, task: Async::Task.current)
	task.async do |subtask|
		subtask.annotate "I'm going to sleep #{duration}s..."
		subtask.sleep duration
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
	subtask.stop
end
```

#### Embedding Reactors

`Async::Reactor#run` will run until the reactor runs out of work to do. To run a single iteration of the reactor, use `Async::Reactor#run_once`

``` ruby
require 'async'

Async.logger.debug!
reactor = Async::Reactor.new

# Run the reactor for 1 second:
reactor.async do |task|
	task.sleep 1
	puts "Finished!"
end

while reactor.run_once
	# Round and round we go!
end
```

You can use this approach to embed the reactor in another event loop.

#### Stopping Reactors

`Async::Reactor#stop` will stop the current reactor and all children tasks.

#### Interrupting Reactors

`Async::Reactor#interrupt` can be called safely from a different thread (or signal handler) and will cause the reactor to invoke `#stop`.

### Resource Management

In order to ensure your resources are cleaned up correctly, make sure you wrap resources appropriately, e.g.:

``` ruby
Async::Reactor.run do
	socket = connect(remote_address) # May raise Async::Stop
	
	begin
		socket.write(...) # May raise Async::Stop
		socket.read(...) # May raise Async::Stop
	ensure
		socket.close
	end
end
```

As tasks run synchronously until they yield back to the reactor, you can guarantee this model works correctly. While in theory `IO#autoclose` allows you to automatically close file descriptors when they go out of scope via the GC, it may produce unpredictable behavour (exhaustion of file descriptors, flushing data at odd times), so it's not recommended.

### Exception Handling

`Async::Task` captures and logs exceptions. All unhandled exceptions will cause the enclosing task to enter the `:failed` state. Non-`StandardError` exceptions are re-raised immediately and will generally cause the reactor to fail. This ensures that exceptions will always be visible and cause the program to fail appropriately.

``` ruby
require 'async'

task = Async do
	# Exception will be logged and task will be failed.
	raise "Boom"
end

puts task.status # failed
puts task.result # raises RuntimeError: Boom
```

#### Propagating Exceptions

If a task has finished due to an exception, calling `Task#wait` will re-raise the exception.

``` ruby
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
```

#### Timeouts

You can wrap asynchronous operations in a timeout. This ensures that malicious services don't cause your code to block indefinitely.

``` ruby
require 'async'

Async do |task|
	task.with_timeout(1) do
		task.sleep 100
	rescue Async::TimeoutError
		puts "I timed out!"
	end
end
```

### Reoccurring Timers

Sometimes you need to do some periodic work in a loop.

``` ruby
require 'async'

Async do |task|
	while true
		puts Time.now
		task.sleep 1
	end
end
```

## Caveats

### Enumerators

Due to limitations within Ruby and the nature of this library, it is not possible to use `to_enum` on methods which invoke asynchronous behavior. We hope to [fix this issue in the future](https://github.com/socketry/async/issues/23).

### Blocking Methods in Standard Library

Blocking Ruby methods such as `pop` in the `Queue` class require access to their own threads and will not yield control back to the reactor which can result in a deadlock.  As a substitute for the standard library `Queue`, the `Async::Queue` class can be used.

## Conventions

### Nesting Tasks

`Async::Barrier` and `Async::Semaphore` are designed to be compatible with each other, and with other tasks that nest `#async` invocations. There are other similar situations where you may want to pass in a parent task, e.g. `Async::IO::Endpoint#bind`.

``` ruby
barrier = Async::Barrier.new
semaphore = Async::Semaphore.new(2)

semaphore.async(parent: barrier) do
	# ...
end
```

A `parent:` in this context is anything that responds to `#async` in the same way that `Async::Task` responds to `#async`. In situations where you strictly depend on the interface of `Async::Task`, use the `task: Task.current` pattern.

## Contributing

1.  Fork it
2.  Create your feature branch (`git checkout -b my-new-feature`)
3.  Commit your changes (`git commit -am 'Add some feature'`)
4.  Push to the branch (`git push origin my-new-feature`)
5.  Create new Pull Request

## See Also

  - [async-io](https://github.com/socketry/async-io) — Asynchronous networking and sockets.
  - [async-http](https://github.com/socketry/async-http) — Asynchronous HTTP client/server.
  - [async-process](https://github.com/socketry/async-process) — Asynchronous process spawning/waiting.
  - [async-websocket](https://github.com/socketry/async-websocket) — Asynchronous client and server websockets.
  - [async-dns](https://github.com/socketry/async-dns) — Asynchronous DNS resolver and server.
  - [async-rspec](https://github.com/socketry/async-rspec) — Shared contexts for running async specs.

### Projects Using Async

  - [ciri](https://github.com/ciri-ethereum/ciri) — An Ethereum implementation written in Ruby.
  - [falcon](https://github.com/socketry/falcon) — A rack compatible server built on top of `async-http`.
  - [rubydns](https://github.com/ioquatix/rubydns) — A easy to use Ruby DNS server.
  - [slack-ruby-bot](https://github.com/slack-ruby/slack-ruby-bot) — A client for making slack bots.

## License

Released under the MIT license.

Copyright, 2017, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
