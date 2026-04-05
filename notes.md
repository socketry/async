## Root Cause Analysis

The error `stream closed in another thread (IOError)` comes from `ruby_error_stream_closed` being enqueued as a pending thread interrupt by `thread_io_close_notify_all` in CRuby's `thread.c`.

### Call chain

1. The Select backend's `Interrupt` helper holds a `@input`/`@output` pipe. A fiber loops doing `io_wait(@fiber, @input, IO::READABLE)`.
2. When the selector is closed, `@input.close` and `@output.close` are called.
3. CRuby's `rb_thread_io_close_interrupt` → `thread_io_close_notify_all` iterates all blocking operations on the closed IO.
4. For each blocked fiber it tries `rb_fiber_scheduler_fiber_interrupt`. **The Select backend does not implement `fiber_interrupt`**, so this returns `Qundef`.
5. The fallback path then calls `rb_threadptr_pending_interrupt_enque(thread, ruby_error_stream_closed)` + `rb_threadptr_interrupt(thread)` — enqueuing the interrupt at the **thread** level.
6. The interrupt fiber itself handles the `IOError` via its `io_wait` loop, but the thread-level interrupt stays in the pending queue.
7. The next call to `rb_thread_check_ints()` anywhere on that thread fires the stale `IOError` — even against a completely unrelated IO.

### Where `rb_thread_check_ints` fires unexpectedly

- `rb_io_wait_readable` / `rb_io_wait_writable` on `EINTR` — any EINTR during a read/write retries and calls `rb_thread_check_ints`.
- `waitpid_no_SIGCHLD` retry loop — `RUBY_VM_CHECK_INTS(w->ec)` after each interrupted `waitpid` call. **This is Failure 2 and 3**: the `Thread.new { Process::Status.wait(...) }` block in `Select#process_wait` (line 263) gets the stale interrupt fired here.
- `io_fd_check_closed` when `fd < 0` — less likely but another path.
- Verbose test output: sus writing to stdout/stderr (which is a pipe in CI) can be interrupted by a signal, hitting `rb_io_wait_writable` → `rb_thread_check_ints`, detonating the stale interrupt. **This makes verbose mode more likely to surface the bug.**

### Fix

The Select backend needs to implement `fiber_interrupt` so that `thread_io_close_notify_all` gets a non-`Qundef` result and does not fall through to the thread-level pending interrupt enqueue. With `fiber_interrupt` implemented, closing the interrupt pipe would cleanly transfer the error into the waiting fiber only, without polluting the thread's interrupt queue.

---

Failure 1:

```
		describe Async::Promise
			describe #wait
				describe #wait it handles spurious wake-ups gracefully test/async/promise.rb:836
					expect :success to
						be == :success
							✓ assertion passed test/async/promise.rb:856
#<Thread:0x0000000120ff8860 test/async/promise.rb:840 run> terminated with exception (report_on_exception is true):
stream closed in another thread (IOError)
```

Failure 2:

```
	file test/process.rb
		describe Process
			describe .wait2
				describe .wait2 it can wait on child process test/process.rb:12
					expect #<Async::Reactor:0x00000000000023c0> to
						receive process_wait
					expect #<Process::Status: pid 2382 exit 0> to
						be success?
							✓ assertion passed test/process.rb:17
#<Thread:0x00007f9c3ac473f8 /home/runner/work/async/async/vendor/bundle/ruby/4.0.0/gems/io-event-1.15.0/lib/io/event/selector/select.rb:263 run> terminated with exception (report_on_exception is true):
stream closed in another thread (IOError)
```

Failure 3:

```
	file test/process/fork.rb
		describe Process
			describe .fork
				describe .fork it can fork with block form test/process/fork.rb:12
					expect "hello" to
						be == "hello"
							✓ assertion passed test/process/fork.rb:23
#<Thread:0x00007f99d0879fa8 /home/runner/work/async/async/vendor/bundle/ruby/3.4.0/gems/io-event-1.15.0/lib/io/event/selector/select.rb:263 run> terminated with exception (report_on_exception is true):
stream closed in another thread (IOError)
```

Failure 4:

```
describe IO with #close it can interrupt reading thread when closing from a fiber test/io.rb:171
	⚠ IOError: stream closed in another thread
		test/io.rb:178 IO#read
		test/io.rb:178 block (5 levels) in <top (required)>
```
