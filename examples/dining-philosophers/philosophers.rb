#!/usr/bin/env ruby

require 'async'
require 'async/semaphore'

class Philosopher
	def initialize(name, left_fork, right_fork)
		@name = name
		@left_fork = left_fork
		@right_fork = right_fork
	end

	def think
		puts "#{@name} is thinking."
		sleep(rand(1..3))
		puts "#{@name} has finished thinking."
	end

	def eat
		puts "#{@name} is eating."
		sleep(rand(1..3))
		puts "#{@name} has finished eating."
	end

	def dine
		Sync do |task|
			think
			
			@left_fork.acquire do
				@right_fork.acquire do
					eat
				end
			end
		end
	end
end

# Each philosopher has a name, a left fork, and a right fork.
# - The think method simulates thinking by sleeping for a random duration.
# - The eat method simulates eating by sleeping for a random duration.
# - The dine method is a loop where the philosopher alternates between thinking and eating.
# - It uses async blocks to pick up the left and right forks before eating.

# This code ensures that philosophers can think and eat concurrently while properly handling the synchronization of forks to avoid conflicts.
Async do |task|
	# We create an array of Async::Semaphore objects to represent the forks. Each semaphore is initialized with a count of 1, representing a single fork.
	forks = Array.new(5) {Async::Semaphore.new(1)}
	
	# We create an array of philosophers, each of whom gets two forks (their left and right neighbors).
	philosophers = Array.new(5) do |i|
		Philosopher.new("Philosopher #{i + 1}", forks[i], forks[(i + 1) % 5])
	end
	
	# We start an async task for each philosopher to run their dine method concurrently.
	philosophers.each do |philosopher|
		task.async do
			philosopher.dine
		end
	end
end