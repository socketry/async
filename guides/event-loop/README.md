# Event Loop

This guide gives an overview of how the event loop is implemented.

## Overview

{ruby Async::Reactor} provides the event loop and sits at the root of any task tree. Work is scheduled by adding {ruby Async::Task} instances to the reactor. When you invoke {ruby Async::Reactor#async}, the parent task is determined by calling {ruby Async::Task.current?} which uses fiber local storage. A slightly more efficient method is to use {ruby Async::Task#async}, which uses `self` as the parent task.

~~~ ruby
require 'async'

def sleepy(duration, task: Async::Task.current)
	task.async do |subtask|
		subtask.annotate "I'm going to sleep #{duration}s..."
		subtask.sleep duration
		puts "I'm done sleeping!"
	end
end

def nested_sleepy(task: Async::Task.current)
	task.async do |subtask|
		subtask.annotate "Invoking sleepy 5 times..."
		5.times do |index|
			sleepy(index, task: subtask)
		end
	end
end

Async do |task|
	task.annotate "Invoking nested_sleepy..."
	subtask = nested_sleepy
	
	# Print out all running tasks in a tree:
	task.print_hierarchy($stderr)
	
	# Kill the subtask
	subtask.stop
end
~~~

### Thread Safety

Most methods of the reactor and related tasks are not thread-safe, so you'd typically have [one reactor per thread or process](https://github.com/socketry/async-container).

### Embedding Reactors

`Async::Reactor#run` will run until the reactor runs out of work to do. To run a single iteration of the reactor, use `Async::Reactor#run_once`

~~~ ruby
require 'async'

Console.logger.debug!
reactor = Async::Reactor.new

# Run the reactor for 1 second:
reactor.async do |task|
	task.sleep 1
	puts "Finished!"
end

while reactor.run_once
	# Round and round we go!
end
~~~

You can use this approach to embed the reactor in another event loop.

### Stopping Reactors

`Async::Reactor#stop` will stop the current reactor and all children tasks.

### Interrupting Reactors

`Async::Reactor#interrupt` can be called safely from a different thread (or signal handler) and will cause the reactor to invoke `#stop`.
