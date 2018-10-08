
require 'async/reactor'

class Callback
	def initialize
		@reactor = Async::Reactor.new
	end
	
	def close
		@reactor.close
	end
	
	# If duration is 0, it will happen immediately after the task is started.
	def run(duration = 0)
		@reactor.run do |task|
			@reactor.after(duration) do
				@reactor.stop
			end
			
			yield(task) if block_given?
		end
	end
end


callback = Callback.new

callback.run do |task|
	while true
		task.sleep(2)
		puts "Hello from task!"
	end
end

while true
	callback.run(0)
	puts "Sleeping for 1 second"
	sleep(1)
end
