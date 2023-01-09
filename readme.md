# ![Async](logo.svg)

Async is a composable asynchronous I/O framework for Ruby based on [io-event](https://github.com/socketry/io-event) and [timers](https://github.com/socketry/timers).

> "Lately I've been looking into `async`, as one of my projects – [tus-ruby-server](https://github.com/janko/tus-ruby-server) – would really benefit from non-blocking I/O. It's really beautifully designed." *– [janko](https://github.com/janko)*

[![Development Status](https://github.com/socketry/async/workflows/Test/badge.svg)](https://github.com/socketry/async/actions?workflow=Test)

## Features

  - Scalable event-driven I/O for Ruby. Thousands of clients per process\!
  - Light weight fiber-based concurrency. No need for callbacks\!
  - Multi-thread/process containers for parallelism.
  - Growing eco-system of event-driven components.

## Usage

Please see the [project documentation](https://socketry.github.io/async).

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

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
  - [rubydns](https://github.com/ioquatix/rubydns) — An easy to use Ruby DNS server.
  - [slack-ruby-bot](https://github.com/slack-ruby/slack-ruby-bot) — A client for making slack bots.
