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

  - [Scheduler](https://socketry.github.io/async/guides/scheduler/index) - This guide gives an overview of how the scheduler is implemented.

  - [Tasks](https://socketry.github.io/async/guides/tasks/index) - This guide explains how asynchronous tasks work and how to use them.

  - [Best Practices](https://socketry.github.io/async/guides/best-practices/index) - This guide gives an overview of best practices for using Async.

  - [Debugging](https://socketry.github.io/async/guides/debugging/index) - This guide explains how to debug issues with programs that use Async.

  - [Thread safety](https://socketry.github.io/async/guides/thread-safety/index) - This guide explains thread safety in Ruby, focusing on fibers and threads, common pitfalls, and best practices to avoid problems like data corruption, race conditions, and deadlocks.

## Releases

Please see the [project releases](https://socketry.github.io/async/releases/index) for all releases.

### v2.35.3

  - `Async::Clock` now implements `#as_json` and `#to_json` for nicer log formatting.

### v2.35.2

  - Improved handling of `Process.fork` on Ruby 4+.
  - Improve `@promise` state handling in `Task#initialize`, preventing incomplete instances being visible to the scheduler.

### v2.35.1

  - Fix incorrect handling of spurious wakeups in `Async::Promise#wait`, which could lead to premature (incorrect) resolution of the promise.

### v2.35.0

  - `Process.fork` is now properly handled by the Async fiber scheduler, ensuring that the scheduler state is correctly reset in the child process after a fork. This prevents issues where the child process inherits the scheduler state from the parent, which could lead to unexpected behavior.

### v2.34.0

  - [`Kernel::Barrier` Convenience Interface](https://socketry.github.io/async/releases/index#kernel::barrier-convenience-interface)

### v2.33.0

  - Introduce `Async::Promise.fulfill` for optional promise resolution.

### v2.32.1

  - Fix typo in documentation.

### v2.32.0

  - Introduce `Queue#waiting_count` and `PriorityQueue#waiting_count`. Generally for statistics/testing purposes only.

### v2.31.0

  - Introduce `Async::Deadline` for precise timeout management in compound operations.

### v2.30.0

  - Add timeout support to `Async::Queue#dequeue` and `Async::Queue#pop` methods.
  - Add timeout support to `Async::PriorityQueue#dequeue` and `Async::PriorityQueue#pop` methods.
  - Add `closed?` method to `Async::PriorityQueue` for full queue interface compatibility.
  - Support non-blocking operations using `timeout: 0` parameter.

## See Also

  - [async-http](https://github.com/socketry/async-http) — Asynchronous HTTP client/server.
  - [falcon](https://github.com/socketry/falcon) — A rack compatible server built on top of `async-http`.
  - [async-websocket](https://github.com/socketry/async-websocket) — Asynchronous client and server websockets.
  - [async-dns](https://github.com/socketry/async-dns) — Asynchronous DNS resolver and server.
  - [toolbox](https://github.com/socketry/toolbox) — GDB & LLDB extensions for debugging Ruby applications with Fibers.

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
