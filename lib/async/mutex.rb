
require_relative 'task'

module Async
	module FiberMutex
		def lock
			if task = Task.current?
				reactor = task.reactor
				
				until self.try_lock
					thread = Thread.new do
						# This is a hack to send a notification when the mutex *might* be available to lock:
						super
						self.unlock
					ensure
						reactor.notify(task.fiber, true)
					end
					
					Task.yield
					thread.join
				end
				
				return true
			else
				super
			end
		end
		
		def synchronize
			self.lock
			
			begin
				yield
			ensure
				self.unlock
			end
		end
	end
	
	::Thread::Mutex.prepend(FiberMutex)
end
