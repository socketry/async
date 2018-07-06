# ![Async](logo.svg)

Async is a composable asynchronous I/O framework for Ruby based on [nio4r] and [timers].

[timers]: https://github.com/socketry/timers
[nio4r]: https://github.com/socketry/nio4r

[![Build Status](https://secure.travis-ci.org/socketry/async.svg)](http://travis-ci.org/socketry/async)
[![Code Climate](https://codeclimate.com/github/socketry/async.svg)](https://codeclimate.com/github/socketry/async)
[![Coverage Status](https://coveralls.io/repos/socketry/async/badge.svg)](https://coveralls.io/r/socketry/async)
[![Gitter](https://badges.gitter.im/join.svg)](https://gitter.im/socketry/async)

## Motivation

Several years ago, I was hosting websites on a server in my garage. Back then, my ADSL modem was very basic, and I wanted to have a DNS server which would resolve to an internal IP address when the domain itself resolved to my public IP. Thus was born [RubyDNS]. This project [was originally built on](https://github.com/ioquatix/rubydns/tree/v0.8.5) top of [EventMachine], but a lack of support for [IPv6 at the time](https://github.com/ioquatix/rubydns/issues/45) and [other problems](https://github.com/ioquatix/rubydns/issues/14), meant that I started looking for other options. Around that time [Celluloid] was picking up steam. I had not encountered actors before and I wanted to learn more about it. So, [I reimplemented RubyDNS on top of Celluloid](https://github.com/ioquatix/rubydns/tree/v0.9.0) and this eventually became the first stable release.

Moving forward, I refactored the internals of RubyDNS into [Celluloid::DNS]. This rewrite helped solidify the design of RubyDNS and to a certain extent it works. However, [unfixed bugs and design problems](https://github.com/celluloid/celluloid/pull/710) in Celluloid meant that RubyDNS 2.0 was delayed by almost 2 years. I wasn't happy releasing it with known bugs and problems. After sitting on the problem for a while, and thinking about possible solutions, I decided to build a small event reactor using [nio4r] and [timers], the core parts of [Celluloid::IO] which made it work so well. The result is this project.

In addition, there is a [similarly designed C++ library of the same name](https://github.com/kurocha/async). These two libraries share similar design principles, but are different in some areas due to the underlying semantic differences of the languages.

[Celluloid]: https://github.com/celluloid/celluloid
[Celluloid::IO]: https://github.com/celluloid/celluloid-io
[Celluloid::DNS]: https://github.com/celluloid/celluloid-dns
[EventMachine]: https://github.com/eventmachine/eventmachine
[RubyDNS]: https://github.com/ioquatix/rubydns

## Installation

Add this line to your application's Gemfile:

```ruby
gem "async"
```

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install async

## Usage

`Async::Reactor` is the top level IO reactor, and runs multiple tasks asynchronously. The reactor itself is not thread-safe, so you'd typically have [one reactor per thread or process](https://github.com/socketry/async-container).

An `Async::Task` runs using a `Fiber` and blocking operations e.g. `sleep`, `read`, `write` yield control until the operation can succeed.

The design of this core library is deliberately simple in scope. Additional libraries provide asynchronous networking, process management, etc. It's likely you will prefer to depend on `async-io` for actual wrappers around `IO` and `Socket`.

### Main Entry Points

#### `Async::Reactor.run`

The highest level entry point is `Async::Reactor.run`. It's useful if you are building a library and you want well defined asynchronous semantics.

```ruby
def run_server
	Async::Reactor.run do |task|
		# ... acccept connections
	end
end
```

If `Async::Reactor.run(&block)` happens within an existing reactor, it will schedule an asynchronous task and return. If `Async::Reactor.run(&block)` happens outside of an existing reactor, it will create a reactor, schedule the asynchronous task, and block until it completes. The task is scheduled by calling `Async::Reactor.async(&block)`.

This puts the power into the hands of the client, who can either have blocking or non-blocking behaviour by explicitly wrapping the call in a reactor (or not). The cost of using `Async::Reactor.run` is minimal for initialization/server setup, but is not ideal for per-connection tasks.

#### `Async::Task#async`

If you can guarantee you are running within a task, and have access to it (e.g. via an argument), you can efficiently schedule new tasks using the `Async::Task#async(&block)` method.

```ruby
def do_request(task: Task.current)
	task.async do
		# ... do some actual work
	end
end
```

This method effectively creates a child task. It's the most efficient way to schedule a task. The task is executed until the first blocking operation, at which point it will yield control and `#async` will return. The result of this method is the task itself.

### Reactor Tree

`Async::Reactor` and `Async::Task` form nodes in a tree. Reactors and tasks can spawn children tasks. When you invoke `Async::Reactor#async`, the parent task is determined by calling `Async::Task.current?` which uses fiber local storage. A slightly more efficient method is to use `Async::Task#async`, which uses `self` as the parent task.

When invoking `Async::Reactor#stop`, you will stop *all* children tasks of that reactor. Tasks will raise `Async::Stop` if they are in a blocking operation. In addition, it's possible to only stop a sub-tree by issuing `Async::Task#stop`, which will stop that task and all it's children (recursively). When you design a server, you should return the task back to the caller. They can use this task to stop the server if needed, independently of any other unrelated tasks within the reactor, and it will correctly clean up all related tasks.

### Resource Management

In order to ensure your resources are cleaned up correctly, make sure you wrap resources appropriately, e.g.:

```ruby
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

## Caveats

### Enumerators

Due to limitations within Ruby and the nature of this library, it is not possible to use `to_enum` on methods which invoke asynchronous behavior. We hope to [fix this issue in the future](https://github.com/socketry/async/issues/23).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## See Also

- [async-io](https://github.com/socketry/async-io) — Asynchronous networking and sockets.
- [async-http](https://github.com/socketry/async-http) — Asynchronous HTTP client/server.
- [falcon](https://github.com/socketry/falcon) — A rack compatible server built on top of `async-http`.
- [async-process](https://github.com/socketry/async-process) — Asynchronous process spawning/waiting.
- [async-websocket](https://github.com/socketry/async-websocket) — Asynchronous client and server websockets.
- [async-dns](https://github.com/socketry/async-dns) — Asynchronous DNS resolver and server.
- [async-rspec](https://github.com/socketry/async-rspec) — Shared contexts for running async specs.
- [rubydns](https://github.com/ioquatix/rubydns) — A easy to use Ruby DNS server.

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
