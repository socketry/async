# Compatibility

Async is compatible with a wide range of different Ruby versions.

## Stable V1

The `stable-v1` branch of async is compatible with Ruby 2.5+ & TruffleRuby, and partially compatible with JRuby.

Because it was designed with the interfaces available in Ruby 2.x, the following limitations apply:

- {Async::Task} implements context switching using `Fiber.yield` and `Fiber.resume`. This means that `Async` may not be compatible with code which uses fibers for flow control, e.g. `Enumerator`.
- {Async::Reactor} is unable to intercept blocking operations with native interfaces. You need to use the wrappers provided by `Async::IO`.
- DNS resolution is blocking.

## Main

The `main` branch of async is compatible with Ruby 3.0.2+, and partially compatible with TruffleRuby. JRuby is currently incompatble.

- {Async::Task} uses `Fiber#transfer`for scheduling so it is compatible with all other usage of Fiber.
- {Async::Reactor} implements the Fiber scheduler interface and is compatible with a wide range of non-blocking operations, including DNS, `Process.wait`, etc.
- External C libraries that use blocking operations may still block.
- Ruby 3.0 has some bugs in the non-blocking thread primitives which have not been backported. Ruby 3.1+ solves these problems.
