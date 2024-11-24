# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require "etc"

module Async
	# A simple work pool that offloads work to a background thread.
	#
	# @private
	class WorkerPool
		class Promise
			def initialize(work)
				@work = work
				@state = :pending
				@value = nil
				@guard = ::Mutex.new
				@condition = ::ConditionVariable.new
				@thread = nil
			end
			
			def call
				work = nil
				
				@guard.synchronize do
					@thread = ::Thread.current
					
					return unless work = @work
				end
				
				resolve(work.call)
			rescue Exception => error
				reject(error)
			end
			
			private def resolve(value)
				@guard.synchronize do
					@work = nil
					@thread = nil
					@value = value
					@state = :resolved
					@condition.broadcast
				end
			end
			
			private def reject(error)
				@guard.synchronize do
					@work = nil
					@thread = nil
					@value = error
					@state = :failed
					@condition.broadcast
				end
			end
			
			def cancel
				return unless @work
				
				@guard.synchronize do
					@work = nil
					@state = :cancelled
					@thread&.raise(Interrupt)
				end
			end
			
			def wait
				@guard.synchronize do
					while @state == :pending
						@condition.wait(@guard)
					end
					
					if @state == :failed
						raise @value
					else
						return @value
					end
				end
			end
		end
		
		# A handle to the work being done.
		class Worker
			def initialize
				@work = ::Thread::Queue.new
				@thread = ::Thread.new(&method(:run))
			end
			
			def run
				while work = @work.pop
					work.call
				end
			end
			
			def close
				if thread = @thread
					@thread = nil
					thread.kill
				end
			end
			
			# Call the work and notify the scheduler when it is done.
			def call(work)
				promise = Promise.new(work)
				
				@work.push(promise)
				
				begin
					return promise.wait
				ensure
					promise.cancel
				end
			end
		end
		
		# Create a new work pool.
		#
		# @parameter size [Integer] The number of threads to use.
		def initialize(size: Etc.nprocessors)
			@ready = ::Thread::Queue.new
			
			size.times do
				@ready.push(Worker.new)
			end
		end
		
		# Close the work pool. Kills all outstanding work.
		def close
			if ready = @ready
				@ready = nil
				ready.close
				
				while worker = ready.pop
					worker.close
				end
			end
		end
		
		# Offload work to a thread.
		#
		# @parameter work [Proc] The work to be done.
		def call(work)
			if ready = @ready
				worker = ready.pop
				
				begin
					worker.call(work)
				ensure
					ready.push(worker)
				end
			else
				raise RuntimeError, "No worker available!"
			end
		end
	end
end
