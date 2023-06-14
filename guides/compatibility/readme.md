# Compatibility

This guide gives an overview of the compatibility of Async with Ruby and other frameworks.


## Ruby

Async has two main branches, `stable-v1` and `main`.

### Stable V1

The `stable-v1` branch of async is compatible with Ruby 2.5+ & TruffleRuby, and partially compatible with JRuby.

Because it was designed with the interfaces available in Ruby 2.x, the following limitations apply:

- {ruby Async::Task} implements context switching using {ruby Fiber.yield} and {ruby Fiber.resume}. This means that {ruby Async} may not be compatible with code which uses fibers for flow control, e.g. {ruby Enumerator}.
- {ruby Async::Reactor} is unable to intercept blocking operations with native interfaces. You need to use the wrappers provided by {ruby Async::IO}.
- DNS resolution is blocking.

### Main

The `main` branch of async is compatible with Ruby 3.0.2+, and partially compatible with TruffleRuby. JRuby is currently incompatble.

Because it was designed with the interfaces available in Ruby 3.x, it supports the fiber scheduler which provides transparent concurrency.

- {ruby Async::Task} uses {ruby Fiber#transfer} for scheduling so it is compatible with all other usage of Fiber.
- {ruby Async::Reactor} implements the Fiber scheduler interface and is compatible with a wide range of non-blocking operations, including DNS, {ruby Process.wait}, etc.
- External C libraries that use blocking operations may still block.
- Ruby <= 3.0.2 has some bugs in its non-blocking thread primitives. These should be fixed in 3.0.3+.

## Rails

Rails itself is generally compatible with Async and the fiber scheduler, but certain parts of Rails are not compatible with Async and have ossified ("accidental standardization") around thread-per-request as a general model. These issues are fully addressed in Rails v7.1+, which supports Rack 3 and fiber-per-request.

### Enabling Fiber Per Request

Ensure you have the following configuration in your application:

```ruby
class Application < Rails::Application
	config.active_support.isolation_level = :fiber
end
```

### Pain Points

- ActiveRecord with the latest version of the `pg` gem supports concurrent database queries.
- ActiveRecord with `mysql2` gem does not support asynchronous queries. Potentially fixed by <https://github.com/trilogy-libraries/trilogy>.
- `ActiveSupport::CurrentAttributes` is per-isolated execution context. This means that child threads or fibers won't share the state. If you desire this, use `Fiber.storage` instead.
