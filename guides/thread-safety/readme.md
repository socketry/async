# Thread safety

This guide explains thread safety in Ruby, focusing on fibers and threads, common pitfalls, and best practices to avoid problems like data corruption, race conditions, and deadlocks.

## Usage

You can use this guide to understand how to write thread-safe code in Ruby, especially when using fibers and threads. It covers key principles, common patterns, and unsafe practices, along with safe alternatives.

### Agents

When analyzing existing projects, you should check files one by one, looking for problematic patterns and unsafe practices as outlined in this guide. You should report these issues and suggest safe alternatives.

## Key Issues

- **Data corruption is the primary concern** - prevention is absolutely critical.
- **Isolation should be the default** - operations should not share mutable state.
  - **Shared mutable state should be avoided**. Prefer pure functions, immutable objects, and dependency injection.
- **Assume that code will be executed concurrently** by multiple fibers, threads and processes.
- **Assume that code may context switch at any time**, but especially during I/O operations.
  - I/O operations include network calls, file I/O, database queries, etc.
  - Other context switch points include `Fiber.yield`, `sleep`, waiting on child processes, DNS queries, and interrupts (signal handling).
- **Fibers and threads are NOT the same thing**, however they do share similar safety requirements.
- **C extensions e.g. C/Rust etc. can block the fiber scheduler entirely**.
  - Native code, when implemented correctly, is usually okay, but bugs can exist anywhere, even in mature code.

## Quick Reference

| Unsafe Pattern / Problem                       | Safe Alternative / Solution                            | Note / Rationale                                   |
| :--------------------------------------------- | :----------------------------------------------------- | :------------------------------------------------- |
| `@data \|\|= load_data`                        | `@mutex.synchronize { @data \|\|= load_data }`         | `\|\|=` is not atomic; use double-checked locking. |
| `@shared_array << item`                        | `Thread::Mutex` or `Thread::Queue`                     | Use a mutex, or better, `Queue` for coordination.  |
| `@shared_hash[key] = value`                    | `Thread::Mutex` or `Concurrent::Map`                   | Use a mutex or a concurrent data structure.        |
| `@@class_var`                                  | Dependency injection / Instance state                  | Class vars create spooky shared state.             |
| Class attribute / `class_attribute`            | Constructor arg or method param                        | Pass state explicitly to avoid coupling.           |
| Shared mutable state                           | Immutability / Isolation / Pure functions              | Avoid sharing mutable state if possible.           |
| Memoization with shared Hash                   | `Mutex` or `Concurrent::Map`                           | Hash memoization is not thread-safe.               |
| Lazy init: `@mutex \|\|= Mutex.new`            | Initialize eagerly                                     | Mutex creation must itself be thread-safe.         |
| Shared connection (e.g. DB client)             | Connection pool                                        | Never share non-thread-safe connections.           |
| Array/Hash iteration while mutating            | Synchronize all access with `Mutex` / copy for enum    | Don’t mutate while enumerating.                    |
| `Thread.current[:key] = value` for per-request | `Fiber[:key] = value` or pass context                  | Prefer fiber-local or explicit context passing.    |
| Waiting on state with busy-wait                | `Mutex` + `ConditionVariable`                          | Use proper synchronization.                        |
| "Time of check, time of use" on files          | Atomic file ops / use database / transaction           | Use atomic operations to avoid TOCTOU.             |
| Nested mutex acquisition                       | Minimise lock scope, avoid recursion                   | Design locking to avoid deadlocks.                 |
| C extensions blocking fibers                   | Use thread pool / offload blocking ops                 | Avoid blocking the event loop in async code.       |

## Fibers vs Threads in Ruby

Fibers and threads are both primitives which allow for concurrent execution in Ruby. The main difference is that threads are preemptively scheduled by the operating system, while fibers are cooperatively scheduled by the Ruby interpreter. That makes fibers slightly more predictable in terms of execution order, but they still share many of the same safety concerns.

### Fibers

- **Cooperative multitasking** (usually) within a single thread.
- **No preemption** and greedy execution may cause latency issues if a fiber does not yield.
- **Explicit yield points** including I/O operations, `Fiber.yield`, `sleep`, etc.
- **Light weight context switching** due to user-space coroutine implementations.
- **Limited parallelism** if `rb_nogvl` operations can be offloaded to a worker pool.

### Threads

- **Preemptive multitasking** with native OS threads and within the Ruby thread scheduler.
- **Can be interrupted** at any point by the interpreter.
- **Expensive context switching** due operating system overheads and contention within the Ruby interpreter.
- **Limited parallelism** if `rb_nogvl` allows other threads to execute.

## Common patterns with potential issues

The most fundamental issue that underpins all "thread safety issues" is **shared mutable state**. That is because in the presence of multiple execution contexts, such as fibers or threads, shared mutable state creates a combinatorial explosion of possible execution paths, many of which may be undesirable or incorrect. Coordination primitives (like `Mutex`) exist to constrain the combinatorial explosion of possible program states, but they are not a silver bullet and can introduce their own issues like deadlocks, contention, and performance bottlenecks. 

Therefore, the best practice is to avoid shared mutable state whenever possible. Isolation, immutability, and pure functions should be the default where possible, and shared mutable state should be the exception, not the rule.

### Shared mutable state

Shared mutable state, including class instance variables accessed by multiple threads or fibers, is problematic and should be avoided. This includes class instance variables, module variables, and any mutable objects that are shared across threads or fibers.
  
```ruby
class CurrencyConverter
  def initialize
    @exchange_rates = {} # Issue: Shared mutable state
  end
  
  def update_rate(currency, rate)
    # Issue: Multiple threads can modify @exchange_rates concurrently
    @exchange_rates[currency] = rate
  end
  
  def convert(amount, from_currency, to_currency)
    # Issue: If @exchange_rates is modified while this method runs, it can lead to incorrect conversions
    rate = @exchange_rates[from_currency] / @exchange_rates[to_currency]
    amount * rate
  end
end
```

**Why is this problematic?**: Multiple threads or fibers can modify the shared state concurrently, leading to race conditions and inconsistent data.

#### Better alternatives

- Do not share mutable state across threads or fibers.
- Use immutable objects or pure functions that do not rely on shared mutable state.
- Use locking (`Mutex`) or concurrent data structures (if available) to protect shared mutable state.

### Class Variables with shared state

Class variables (`@@variable`) and class attributes (`class_attribute`) represent a design problem because they lack isolation and can lead to unexpected behavior if mutated. As they are shared across the entire inheritance hierarchy, they can cause "spooky action at a distance" where changes in one part of the codebase affect other parts in unexpected ways.

```ruby
class GlobalConfig
  @@settings = {} # Issue: Class variables are shared across inheritance

  def set(key, value)
    @@settings[key] = value
  end

  def get(key)
    @@settings[key]
  end
end

class UserConfig < GlobalConfig
end

GlobalConfig.new.set(:foo, 42)
# Issue: UserConfig inherits from GlobalConfig, so it shares the same @@settings (lack of isolation):
UserConfig.new.get(:foo) # => 42
```

**Why is this problematic?**: Class variables and class instance variables are shared across the entire inheritance hierarchy, creating unnecessary coupling and making it difficult to reason about state changes. This can lead to unexpected behavior, especially in larger codebases or when using libraries that modify class variables.

#### Better alternatives

- Inject configuration or state through method parameters or constructor arguments.
- Simply avoid if possible.

### Lazy Initialization

Lazy initialization is a common pattern in Ruby, but the `||=` operator is not atomic and can lead to race conditions.

```ruby
class Loader
  def self.data
    @data ||= JSON.load_file('data.json')
  end
end
```

**Why is this problematic?**: Multiple threads can see `@data` is `nil` simultaneously on shared mutable data. They will both call `JSON.load_file` concurrently, and each receive different instances of `@data` (althought only one will actually be assigned). This can lead to inconsistent data being used across threads or fibers.

This could cause situations where `self.data != self.data` for example, or modifications to `self.data` in one thread may be lost and not visible in another thread. It should also be noted that some operations are more likely to context switch, such as I/O operations, which could exacerbate this issue.

#### Potential fix with `Mutex`

```ruby
class Loader
  @mutex = Mutex.new

  def self.data
    # Double-checked locking pattern:
    return @data if @data

    @mutex.synchronize do
      return @data if @data

      # Now we are sure that @data is nil, we can safely fetch it:
      @data = JSON.load_file('data.json')
    end

    return @data
  end
end
```

In addition, it should be noted that lazy initialization of a `Mutex` (and other synchronization primitives) is **always** a problem and should be avoided. This is because the `Mutex` itself may not be initialized when multiple threads attempt to access it concurrently, leading to multiple threads using different mutex instances:

```ruby
class Loader
  def self.data
    @mutex ||= Mutex.new # Issue: Not thread-safe

    @mutex.synchronize do
      # Double-checked locking pattern:
      return @data if @data

      # Now we are sure that @data is nil, we can safely fetch it:
      @data = JSON.load_file('data.json')
    end

    return @data
  end
end
```

#### Safe if instances are not shared

In the case that each instance is only accessed by a single thread or fiber, memoization can be safe:

```ruby
class Loader
  def things
    # Safe: each instance has its own @things
    @things ||= compute_things
  end
end

def do_something
  loader = Loader.new
  loader.things # Safe: only accessed by this thread/fiber
end
```

### Memoization with `Hash` caches

Like lazy initialization, memoization using `Hash` caches can lead to race conditions if not handled properly.

```ruby
class ExpensiveComputation
  @cache = {}

  def self.compute(key)
    @cache[key] ||= expensive_operation(key) # Issue: Not thread-safe
  end
end
```

**Why is this problematic?**: Multiple threads can see `@cache[key]` is `nil` simultaneously, leading to multiple calls to `expensive_operation(key)` which is both inefficient and can lead to inconsistent results if the operation is not idempotent.

#### Potential fix with `Mutex`

Note that this mutex creates contention on all calls to `compute`, which can be a performance bottleneck if the operation is expensive and called frequently.

```ruby
class ExpensiveComputation
  @cache = {}
  @mutex = Mutex.new

  def self.compute(key)
    @mutex.synchronize do
      @cache[key] ||= expensive_operation(key)
    end
  end
end
```

#### Potential fix with `Concurrent::Map`

```ruby
class ExpensiveComputation
  @cache = Concurrent::Map.new

  def self.compute(key)
    @cache.compute_if_absent(key) do
      expensive_operation(key)
    end
  end
end
```

You should avoid `Concurrent::Hash` as it's just an alias for `Hash` and does not provide any thread-safety guarantees.

### Aggregating results with `Array`

Aggregating results from multiple threads or fibers using shared `Array` instance is generally safe in Ruby, but can lead to issues if you are trying to coordinate completion of multiple threads or fibers.

```ruby
done = []
threads = []

5.times do |i|
	threads << Thread.new do
		# Simulate some work
		sleep(rand(0.1..0.5))
		done << i
	end
end

# Risk: The threads may not be finished, so `done` is likely incomplete!
puts "Done: #{done.inspect}"
```

**Why is this problematic?**: Trying to wait for the first item (or any subset) to be added to `done` can lead to faulty behaviour as there is no actual coordination between the threads and there is no real error handling. The threads are waited on in creation order, but the items in `done` may not be in the same order, or may not even be present at all if a thread is still running.

#### Potential fix with `Thread#join`

Using `Thread#join` ensures that all threads have completed before accessing the results:

```ruby
done = []

threads = 5.times.map do |i|
	Thread.new do
		# Simulate some work
		sleep(rand(0.1..0.5))
		done << i
	end
end

threads.each(&:join) # Wait for all threads to complete
puts "Done: #{done.inspect}" # Output: Done: [0, 1, 2, 3, 4]
```

### Shared connections

Sharing network connections, database connections, or other resources across threads or fibers can lead to invalid state or unexpected behavior.

```ruby
client = Database.connect

Thread.new do
  results = client.query("SELECT * FROM users")
end

Thread.new do
  results = client.query("SELECT * FROM products")
end
```

**Why is this problematic?**: If the `client` is not thread-safe, and does not handle concurrent queries properly (e.g. by using a connection pool, or explicit multiplexing), it is unlikely that the above code will work as expected. It is possible that the queries will interfere with each other, leading to inconsistent results or even errors.

#### Potential fix with connection pools

Using a connection pool can help manage shared connections safely:

```ruby
require 'connection_pool'
pool = ConnectionPool.new(size: 5, timeout: 5) do
  Database.connect
end

Thread.new do
  pool.with do |client|
    results = client.query("SELECT * FROM users")
  end
end

Thread.new do
  pool.with do |client|
    results = client.query("SELECT * FROM products")
  end
end
```

### Enumeration of shared mutable state

Enumerating shared mutable container (e.g. `Array` or `Hash`) can cause consistency issues if the state is modified during enumeration. This can lead to unexpected behavior, such as missing or duplicated elements.

```ruby
class SharedList
  def initialize
    @list = []
  end

  def add(item)
    @list << item
  end

  def each(&block)
    # Issue: Modifications during enumeration can lead to inconsistent state
    @list.each(&block)
  end
end
```

In addition, adding or deleting items from a list while iterating over it can lead to errors or unexpected behaviour.

**Why is this problematic?**: If another thread modifies `@list` while it is being enumerated, it can lead to missing or duplicated items, or even raise an error if the underlying data structure is modified during iteration.

#### Potential fix with `Mutex`

To ensure that the enumeration is safe, you can use a `Mutex` to synchronize access to the shared state:

```ruby
class SharedList
  def initialize
    @list = []
    @mutex = Mutex.new
  end

  def add(item)
    @mutex.synchronize do
      @list << item
    end
  end

  def each(&block)
    @mutex.synchronize do
      @list.each(&block)
    end
  end
end
```

#### Potential fix with deferred operations

Alternatively, you can defer operations that modify the shared state until after the enumeration is complete:

```ruby
stale = []
shared_list.each do |item|
  if item.stale?
    stale << item
  end
end

stale.each do |item|
  shared_list.remove(item)
end
```

Or better yet, use immutable data structures or pure functions that do not rely on shared mutable state:

```ruby
fresh = []
shared_list.each do |item|
  fresh << item unless item.stale?
end

shared_list.replace(fresh) # Replace the entire list with a new one
```

### Internal Race Conditions

Race conditions occur when state changes in an unpredictable way due to concurrent access. This can happen with shared mutable state, lazy initialization, or any operation that modifies state without proper synchronization, leading to deadlocks or inconsistent data.

```ruby
while system.busy?
  system.wait
end
```

**Why is this problematic?**: If, between the call to `system.busy?` and `system.wait`, another thread modifies the state of `system`, such that it is no longer busy, the current thread may wait indefinitely, leading to a deadlock.

#### Potential fix with `Mutex` and `ConditionVariable`

If you are able to modify the state transition logic of the shared resource, you can use a `Mutex` and `ConditionVariable` to ensure that the state is checked and modified atomically:

```ruby
class System
  def initialize
    @mutex = Mutex.new
    @condition = ConditionVariable.new
    @usage = 0
  end

  def release
    @mutex.synchronize do
      @usage -= 1
      @condition.signal if @usage == 0
    end
  end

  def wait_until_free
    @mutex.synchronize do
      while @usage > 0
        @condition.wait(@mutex)
      end
    end
  end
end
```

### External Race Conditions

External resources can also lead to "time of check to time of use" issues, where the state of the resource changes between checking its status and using it.

```ruby
if File.exist?('cache.json')
  @data = File.read('cache.json')
else
  @data = fetch_data_from_api
  File.write('cache.json', @data)
end
```

**Why is this problematic?**: If another thread deletes `cache.json` after the check but before the read, the read will fail, leading to an error or inconsistent state.

This can apply to any external resource, such as files, databases, or network resources and can be extremely difficult to mitigate if proper synchronization is not available (e.g. database transactions).

#### Potential fix for external resources

Using content-addressable storage and atomic file operations can help avoid race conditions when accessing shared resources on the filesystem

```ruby
begin
  File.read('cache.json')
rescue Errno::ENOENT
  File.open('cache.json', 'w') do |file|
    file.flock(File::LOCK_EX)
    file.write(fetch_data_from_api)
  end
end
```

Modern systems should generally avoid using the filesystem for shared state, and instead use a database or other persistent storage that supports transactions and atomic operations.

### Thread-local storage for "per-request" state

Using actual thread-local storage for "per-request" state can be problematic in Ruby, especially when using fibers. This is because fibers may share the same thread, leading to unexpected behavior if the thread-local is used when "per-request" state is expected.

```ruby
class RequestContext
  def self.current
    Thread.current.thread_variable_get(:request_context) ||
      Thread.current.thread_variable_set(:request_context, Hash.new)
  end
end
```

**Why is this problematic?**: If fibers are used for individual requests, they may share the same thread, leading to unexpected behavior when accessing `Thread.current.thread_variable_get(:request_context)`. This can result in data being shared across requests unintentionally, leading to data corruption or unexpected behavior.

In addition, some libraries may use `Thread.current` as a key in a hash or other data structure to store per-request state. This can be problematic for the same reason, since multiple requests may share the same thread and therefore the same key, leading to data being shared across requests unintentionally. This can be a problem for both concurrent and sequential requests, for example if the state is not cleaned up properly between requests, incorrect sharing of state can occur.

```ruby
class Pool
  def initialize
    @connections = {}
    @mutex = Mutex.new
  end
  
  def current_connection
    @mutex.synchronize do
      @connections[Thread.current] ||= create_new_connection
    end
  end
end
```

#### Use `Thread.current` for per-request state

Despite the look, this is actually fiber-local and thus scoped to the smallest unit of concurrency in Ruby, which is the fiber. This means that it is safe to use `Thread.current` for per-request state, as long as you are aware that it is actually fiber-local storage.

```ruby
Thread.current[:connection] ||= create_new_connection
```

As a counter point, it not a good idea to use fiber-local storage for a cache, since it will never be shared.

#### Use `Fiber[key]` for per-request state

Using `Fiber[key]` can be a better alternative for per-request state as it is scoped to the fiber and is also inherited to child contexts.

```ruby
Fiber[:user_id] = request.session[:user_id] # Set per-request state

jobs.each do |job|
  Thread.new do
    puts "Processing job for user #{Fiber[:user_id]}"
    # Do something with the job...
  end
end
```

#### Use `Fiber.attr` for per-request state

As a direct alternative to `Thread.current`, with a slight performance advantage and readability improvement, you can use `Fiber.attr` to store per-request state. This is scoped to the fiber and is also inherited to child contexts.

```ruby
Fiber.attr :my_application_user_id

Fiber.current.my_application_user_id = request.session[:user_id] # Set per-request state
```

This state is not inherited to child fibers (or threads), so it's use is limited to the current fiber context. It should also be noted that the same technique can be used for threads, e.g. `Thread.attr`, but this has the same issues as `Thread.current.thread_variable_get/set`, since it is scoped to the thread and not the fiber.

### C extensions that block the scheduler

C extensions can block the Ruby scheduler, however the fiber scheduler has a higher risk of being blocked by C extensions than the thread scheduler. That is because `rb_nogvl` allows preemptive scheduling of threads, but fibers are not preemptively scheduled and must yield explicitly. This means that if a C extension blocks the fiber scheduler, it can lead to deadlocks or starvation of other fibers.

### Synchronization primitives

Synchronization primitives like `Mutex`, `ConditionVariable`, and `Queue` are essential for managing shared mutable state safely. However, they can introduce complexity and potential deadlocks if not used carefully.

```ruby
class Counter
  def initialize(count = 0)
    @count = count
    @mutex = Mutex.new
  end

  def increment
    @mutex.synchronize do
      @count += 1
    end
  end

  def times
    @mutex.synchronize do
      @count.times do |i|
        yield i
      end
    end
  end
end

counter = Counter.new
counter.times do |i|
  counter.increment # deadlock
end
```

In general, it is known that `Mutex` can not be composed safely. However, with careful design, it is usually safe to use `Mutex` to protect shared mutable state, as long as you are aware of the potential for deadlocks and contention.

Using recursive mutexes is generally not recommended, as they can lead to complex and hard-to-debug issues. If you find yourself needing recursive locks, it may be a sign that you need to rethink your locking strategy or the design of your code.

#### Potential fix with `Mutex`

As an alternative to the above, reducing the scope of the lock can help avoid deadlocks and contention:

```ruby
class Counter
  # ...

  def times
    count = @mutex.synchronize{@count}

    # Avoid holding the lock while yielding to user code:
    count.times do |i|
      yield i
    end
  end
end
```

## Best Practices for Concurrency in Ruby

1. **Favor pure, isolated, and immutable objects and functions.**
   The safest and easiest way to write concurrent code is to avoid shared mutable state entirely. Isolated objects and pure functions eliminate the risk of race conditions and make reasoning about code much simpler.

2. **Use per-request (or per-fiber) state correctly.**
   When you need to associate state with a request, job, or fiber, prefer explicit context passing, or use fiber-local variables (e.g. `Fiber[:key]`). Avoid using thread-local storage in fiber-based code, as fibers may share threads and this can lead to subtle bugs.

3. **Use synchronization primitives only when sharing is truly necessary.**
   If you must share mutable state (for performance, memory efficiency, or correctness), protect it with the appropriate synchronization primitives:

   * Prefer high-level, lock-free data structures (e.g. `Concurrent::Map`) when possible.
   * If locks are necessary, use fine-grained locking to minimize contention and reduce deadlock risk.
   * Avoid coarse-grained locks except as a last resort, as they can severely limit concurrency and hurt performance.

### Hierarchy of Concurrency Safety

1. **No shared state** (ideal) Isolate state to each thread, fiber, or request—no coordination needed.

2. **Immutable shared state** (very good) Share only data that does not change after creation (constants, frozen objects, etc.).

3. **Synchronized mutable state** (only when unavoidable) Share mutable state only with robust synchronization.

#### When synchronization is needed:

* **Lock-free structures (e.g. `Concurrent::Map`)** Provide safe, concurrent access with high performance and minimal contention.

* **Fine-grained locks** Protect the smallest necessary scope of shared state; avoid holding locks while yielding or running untrusted code.

* **Coarse-grained locks** Protect large areas of code or many data structures at once; use sparingly as this reduces concurrency.
