# frozen_string_literal: true

require_relative 'barrier'

module Async
	class Waiter < Barrier
		def initialize(parent: nil)
			super
			@finished = Async::Condition.new
			@all_tasks = []
			@done = []
		end

		def async(*arguments, parent: (@parent or Task.current), **options)
			t = parent.async(*arguments, **options) do |task|
				yield(task)
			ensure
				@done << task
				@finished.signal
			end

			@tasks << t
			@all_tasks << t
			t
		end

		def wait_for(n = size)
			raise ArgumentError, "'n' cannot be greater than size. Given: #{n}, size: #{size}" if n > size

			while @done.size < n
				@finished.wait
			end

			done = @done.first(n)
			[done, @all_tasks - done]
		ensure
			@tasks.filter!{ |t| !@done.include?(t) }
		end

		def wait(n = size)
			wait_for(n).first.map(&:wait)
		end
	end
end