# ![Async](assets/logo.webp)

Async is a composable asynchronous I/O framework for Ruby based on [io-event](https://github.com/socketry/io-event).

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

  - [Getting Started](https://socketry.github.io/async/guides/getting-started/index) - This guide shows how to add async to your project and run code asynchronously.

  - [Asynchronous Tasks](https://socketry.github.io/async/guides/asynchronous-tasks/index) - This guide explains how asynchronous tasks work and how to use them.

  - [Event Loop](https://socketry.github.io/async/guides/event-loop/index) - This guide gives an overview of how the event loop is implemented.

  - [Compatibility](https://socketry.github.io/async/guides/compatibility/index) - This guide gives an overview of the compatibility of Async with Ruby and other frameworks.

  - [Best Practices](https://socketry.github.io/async/guides/best-practices/index) - This guide gives an overview of best practices for using Async.

  - [Debugging](https://socketry.github.io/async/guides/debugging/index) - This guide explains how to debug issues with programs that use Async.

## Releases

Please see the [project releases](https://socketry.github.io/async/releases/index) for all releases.

### Next

  - [Better Handling of Async and Sync in Nested Fibers](https://socketry.github.io/async/releases/index#better-handling-of-async-and-sync-in-nested-fibers)

## See Also

  - [async-http](https://github.com/socketry/async-http) — Asynchronous HTTP client/server.
  - [async-websocket](https://github.com/socketry/async-websocket) — Asynchronous client and server websockets.
  - [async-dns](https://github.com/socketry/async-dns) — Asynchronous DNS resolver and server.
  - [falcon](https://github.com/socketry/falcon) — A rack compatible server built on top of `async-http`.
  - [rubydns](https://github.com/ioquatix/rubydns) — An easy to use Ruby DNS server.
  - [slack-ruby-bot](https://github.com/slack-ruby/slack-ruby-bot) — A client for making slack bots.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
