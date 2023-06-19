# Best Practices

This guide gives an overview of best practices for using Async.

## Use a top-level `Sync` to denote the root of your program

The `Sync` method ensures your code is running in a reactor or creates one if necessary, and has synchronous semantics, i.e. you do not need to wait on the result of the block.

```ruby
require 'async'

class Packages
	def initialize(urls)
		@urls = urls
	end
	
	def fetch
		Sync do |task|
			@urls.map do |url|
				task.async do
					fetch(url)
				end
			end.map(&:wait)
		end
	end
end
```

## Use a barrier to wait for all tasks to complete

A barrier ensures you don't leak tasks and that all tasks are completed or stopped before progressing.

```ruby
require 'async'

class Packages
	def initialize(urls)
		@urls = urls
	end
	
	def fetch
		Sync do
			barrier = Async::Barrier.new
			
			@urls.map do |url|
				barrier.async do
					fetch(url)
				end
			end.map(&:wait)
		ensure
			barrier.stop
		end
	end
end
```

## Use a semaphore to limit the number of concurrent tasks

Unbounded concurrency is a common source of bugs. Use a semaphore to limit the number of concurrent tasks.

```ruby
require 'async'
require 'async/semaphore'

class Packages
	def initialize(urls)
		@urls = urls
	end
	
	def fetch
		Sync do
			barrier = Async::Barrier.new
			# Only 10 tasks are created at a time:
			semaphore = Async::Semaphore.new(10, parent: barrier)
			
			@urls.map do |url|
				semaphore.async do
					fetch(url)
				end
			end.map(&:wait)
		ensure
			barrier.stop
		end
	end
end
```
