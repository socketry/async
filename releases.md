# Releases

## Unreleased

- Introduce `Async::Queue#push` and `Async::Queue#pop` for compatibility with `::Queue`.

## v2.16.0

### Better Handling of Async and Sync in Nested Fibers

Interleaving bare fibers within `Async` and `Sync` blocks should not cause problems, but it presents a number of issues in the current implementation. Tracking the parent-child relationship between tasks, when they are interleaved with bare fibers, is difficult. The current implementation assumes that if there is no parent task, then it should create a new reactor. This is not always the case, as the parent task might not be visible due to nested Fibers. As a result, `Async` will create a new reactor, trying to stop the existing one, causing major internal consistency issues.

I encountered this issue when trying to use `Async` within a streaming response in Rails. The `protocol-rack` [uses a normal fiber to wrap streaming responses](https://github.com/socketry/protocol-rack/blob/cb1ca44e9deadb9369bdb2ea03416556aa927c5c/lib/protocol/rack/body/streaming.rb#L24-L28), and if you try to use `Async` within it, it will create a new reactor, causing the server to lock up.

Ideally, `Async` and `Sync` helpers should work when any `Fiber.scheduler` is defined. Right now, it's unrealistic to expect `Async::Task` to work in any scheduler, but at the very least, the following should work:

``` ruby
reactor = Async::Reactor.new # internally calls Fiber.set_scheduler

# This should run in the above reactor, rather than creating a new one.
Async do
  puts "Hello World"
end
```

In order to do this, bare `Async` and `Sync` blocks should use `Fiber.scheduler` as a parent if possible.

See <https://github.com/socketry/async/pull/340> for more details.
