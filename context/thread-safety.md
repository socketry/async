# Thread safety

## Critical Context

### Key Principles

- **Data corruption the primary concern** - prevention is absolutely critical
- Assume that code will be executed concurrently by multiple threads/processes
- Assume that code may be suspended and resumed across fiber boundaries
- **Fibers and threads are NOT the same thing**
  - They do however share safety requirements
- **Shared mutable state should be avoided**
- **C extensions e.g. C/Rust etc. can block the fiber scheduler entirely**

## Understanding Fibers vs Threads in Ruby

### Fibers

- **Cooperative multitasking** within a single thread
- **Explicit yield points** (I/O operations, `Fiber.yield`)
- **Separate stack** but shared heap memory within the same thread
- **Faster context switching** than threads (lightweight ~4KB per fiber)
- **No preemption** - code runs until it yields
- **No true parallelism** - all fibers run sequentially within their thread

### Threads

- **Preemptive multitasking** with native OS threads
- **Can be interrupted** at any point by the scheduler
- **Separate stacks** but shared heap memory
- **Heavier context switching** and memory usage
- **Automatic execution** - OS scheduler manages thread execution
- **Limited parallelism in MRI Ruby** due to Global Interpreter Lock (GIL/GVL):
  - True parallelism only during I/O operations (GIL released)
  - True parallelism for C extensions that release the GIL

## Common patterns with potential issues

1. **Memoization patterns** (`||=`)
   - This is NOT atomic and is problematic with class variables and shared mutable data
2. **Class and module variables** (`@@variable`, `class_attribute`)
   - Should never be mutated if used
   - Should be treated as generally problematic
3. **Shared mutable state** (class instance variables accessed by multiple threads/fibers)
   - AVOID
4. **Lazy initialization**
   - Especially on shared mutable sate
5. **Hash and array mutations on shared objects**
6. **C extensions that don't respect the fiber scheduler**
7. **Thread-local storage**
   - When using a fiber scheduler
8. **Synchronization mechanisms** (Mutex, ReadWriteLock)
   - Beware of deadlocks
9. **Concurrent data structures**
   - e.g. `Concurrent::Set` if available can reduce risk of thread safety issues
   - This approach, like all approaches has trade offs
   - Can only be used if the concurrent gem is available

## Common unsafe patterns

### 1. Memoization with `||=` on shared data

```ruby
class Foo
  def self.bar
    # Issue: Two threads can both see @data and can modify it without
    # the other knowing
    @data ||= fetch_next_fizzbuzz_from_fizzbuzz_api
  end
end
```

**Why is this problematic?**: Multiple threads can pass `nil?` checks simultaneously on shared mutable data. Best case this wastes resources, worst case the wrong data is used or data corruption occurs.

**Potential fix with mutex** (WARNING: locks like mutex could cause deadlocks)

```ruby
class Foo
  @mutex = Mutex.new

  def self.bar
    @mutex.synchronize do
      return @data if defined?(@data)
        @data = fetch_next_fizzbuzz_from_fizzbuzz_api
      end
  end
end
```

**Concurrent::Map example** - Only available if the gem is available

```ruby
class Foo
  @cache = Concurrent::Map.new

  def self.bar(key:)
    # Issue: Two threads can both see @cache and both can modify it without
    # the other knowing
    @cache.compute_if_absent(key) { expensive_operation(key) }
  end
end
```

**Safe if instances are not shared**

```ruby
class Foo
  def expensive_operation
    @result ||= calculate # Each instance has own @result
  end
end
```


### 2. Class Variables with shared state

```ruby
class GlobalConfig
  @@settings = {} # Issue: Class variables are shared across inheritance
  @settings = {} # Issue: Shared mutable state without synchronization
end
```

**Why is this problematic?**: Class variables affect the entire inheritance hierarchy, shared mutable state causes race conditions.

**Better alternatives:**

- Use dependency injection for runtime configuration
- Use `Concurrent::Hash.new` if shared state is required and the gem is available
- Simply avoid if possible

## Fiber safety

**Key Difference**: When a fiber yields during I/O, another fiber may access the shared state.

**Problematic - Thread.current in specific cases e.g. request scoped data when paired with servers like Falcon:**

```ruby
class SomeRequestSpecificData
  def track_request(some_request_specific_data)
    # Issue: Thread.current can leak between requests
    Thread.current[:some_request_specific_data] = some_request_specific_data
    external_api_call  # Fiber yields, other requests may be processed
    log("Processing #{Thread.current[:some_request_specific_data]}")  # May have incorrect data!
  end
end
```

**Why is this problematic?**: When a fiber yields during I/O, a fiber based web server may process other requests causing data to become corrupted.

**Better - Use Fiber storage for request data:**

```ruby
class SomeRequestSpecificData
  def track_request(some_request_specific_data)
    Fiber[:some_request_specific_data] = some_request_specific_data
    external_api_call  # Fiber yields
    log("Processing #{Fiber[:some_request_specific_data]}")
  end
end
```

**Acceptable - Thread.current for thread-level concerns:**

```ruby
def some_non_changing_config
    Thread.current[:some_non_changing_config] || default_config
end
```

## Essential Safe Patterns

### 1. Mutex for Critical Sections

```ruby
class ResourcePool
  def initialize
    @resources = []
    @mutex = Mutex.new
  end

  def checkout
    @mutex.synchronize { @resources.pop || create_resource }
  end

  def checkin(resource)
    @mutex.synchronize { @resources.push(resource) }
  end
end
```

### 2. Concurrent Data Structures (if available)

Examples:

```ruby
@cache = Concurrent::Map.new
@config = Concurrent::Hash.new
@enabled = Concurrent::AtomicBoolean.new(false)
```

### 3. Request-Scoped storage when working with web servers

```ruby
# Use Fiber[:key] for request-scoped data
Fiber[:user_context] = current_user

# Access later
def some_controller_method
  Fiber[:user_context]
end
```

## When `||=` can be safe

### 1. Instance variables on unshared objects

When each instance is only accessed by a single thread/fiber:

```ruby
class RequestHandler
  def process_request
    @parser ||= create_parser # Safe: each request has its own handler instance
  end
end
```

### 2. Synchronization primitives

Synchronization objects are designed for concurrent access, so duplicate creation is wasteful but not harmful:

```ruby
class Task
  def wait
    @condition ||= Condition.new # Safe: condition variables handle concurrent access
    @condition.wait
  end
end
```

**Why this is acceptable**:
- Condition variables, mutexes, and semaphores intended for protecting critical sections
- Synchronization still works correctly

### 3. Immutable or effectively immutable objects

```ruby
class Calculator
  def pi
    @pi ||= Math::PI # Safe: immutable value
  end

  def default_config
    @config ||= Config.new.freeze # Safe: frozen object
  end
end
```

## Performance Considerations

### Synchronization Overhead

| Mechanism | Use Case | Performance Impact |
| :---- | :---- | :---- |
| Mutex | General purpose locking | Medium overhead, can cause contention |
| ReadWriteLock | Read-heavy workloads | Better for many readers, few writers |
| Concurrent::* | Lock-free operations | Generally faster, but higher memory usage |
| Atomic operations | Simple counters/flags | Fastest for simple operations |

### Choosing the Right Approach

1. **No shared state** > **Immutable shared state** > **Synchronized mutable state**
2. **Lock-free (Concurrent::*)** > **Fine-grained locks** > **Coarse-grained locks**

## Quick reference

### Thread Safety

| Unsafe Pattern | Safe Alternative |
| :---- | :---- |
| `@data ||= expensive_operation` | `@mutex.synchronize { @data ||= expensive_operation }` |
| `@@class_var` | dependency injection |
| `@shared_array << item` | `@concurrent_set.add(item)` if available or mutex |
| Nested mutex acquisition | Consistent lock ordering |

### Fiber Safety

| Unsafe Pattern | Safe Alternative |
| :---- | :---- |
| `Thread.current[:some_request_based_id] = id` | `Fiber[:some_request_based_id] = id` |
| `@cache ||= {}` (in shared objects) | `Fiber[:cache] ||= {}` |

**Note**: `Thread.current` is ok for thread-level concerns like debugging

## Summary

1. **Prevent data corruption** - Primary production concern
2. **Avoid shared mutable state**
3. **Request isolation** - **Always use `Fiber[:key]` for request-scoped data**
4. **Be aware of performance trade-offs** - Synchronization has costs

### Key Takeaways

- **Fibers != Threads**: Different models but **similar safety requirements**
- **Avoid shared mutable state**: Use dependency injection or immutable objects
- **Prevention over testing**: Write inherently thread-safe code
- **Lock ordering matters**: Prevent deadlocks with consistent acquisition order
- **Snapshot concurrent collections**: Before iteration to avoid inconsistencies

**Critical**: Data corruption from race conditions is the primary concern. Prevention through proper design is a requirement.
