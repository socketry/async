# ![Async](logo.svg)

Async is a composable asynchronous I/O framework for Ruby based on [io-event](https://github.com/socketry/io-event) and
[timers](https://github.com/socketry/timers).

> "Lately I've been looking into `async`, as one of my projects –
> [tus-ruby-server](https://github.com/janko/tus-ruby-server) – would really benefit from non-blocking I/O. It's really
> beautifully designed." *– [janko](https://github.com/janko)*

[![Development Status](https://github.com/socketry/async/workflows/Test/badge.svg)](https://github.com/socketry/async/actions?workflow=Test)

## Features

  - Scalable event-driven I/O for Ruby. Thousands of clients per process\!
  - Light weight fiber-based concurrency. No need for callbacks\!
  - Multi-thread/process containers for parallelism.
  - Growing eco-system of event-driven components.

## Usage

Please see the [project documentation](https://socketry.github.io/async/) for more details.

  - [Getting Started](https://socketry.github.io/async/guides/getting-started/index) - This guide shows how to add
    async to your project and run code asynchronously.

  - [Asynchronous Tasks](https://socketry.github.io/async/guides/asynchronous-tasks/index) - This guide explains how
    asynchronous tasks work and how to use them.

  - [Event Loop](https://socketry.github.io/async/guides/event-loop/index) - This guide gives an overview of how the
    event loop is implemented.

  - [Compatibility](https://socketry.github.io/async/guides/compatibility/index) - This guide gives an overview of the
    compatibility of Async with Ruby and other frameworks.

  - [Best Practices](https://socketry.github.io/async/guides/best-practices/index) - This guide gives an overview of
    best practices for using Async.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

This project uses the [Developer Certificate of Origin](https://developercertificate.org/). All contributors to this project must agree to this document to have their contributions accepted.

### Contributor Covenant

This project is governed by the [Contributor Covenant](https://www.contributor-covenant.org/). All contributors and participants agree to abide by its terms.

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
