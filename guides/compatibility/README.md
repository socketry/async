# Compatibility

Async is compatible with a wide range of different Ruby versions.

## Stable V1

The `stable-v1` branch of async is compatible with Ruby 2.5+ & TruffleRuby, and partially compatible with JRuby.

Because it was designed with the interfaces available in Ruby 2.x, the following limitations apply:

- {ruby Async::Task} implements context switching using {ruby Fiber.yield} and {ruby Fiber.resume}. This means that {ruby Async} may not be compatible with code which uses fibers for flow control, e.g. {ruby Enumerator}.
- {ruby Async::Reactor} is unable to intercept blocking operations with native interfaces. You need to use the wrappers provided by {ruby Async::IO}.
- DNS resolution is blocking.

## Main

The `main` branch of async is compatible with Ruby 3.0.2+, and partially compatible with TruffleRuby. JRuby is currently incompatble.

- {ruby Async::Task} uses {ruby Fiber#transfer} for scheduling so it is compatible with all other usage of Fiber.
- {ruby Async::Reactor} implements the Fiber scheduler interface and is compatible with a wide range of non-blocking operations, including DNS, {ruby Process.wait}, etc.
- External C libraries that use blocking operations may still block.
- Ruby 3.0 has some bugs in the non-blocking thread primitives which have not been backported. Ruby 3.1+ solves these problems.
