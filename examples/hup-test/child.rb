#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2023-2024, by Samuel Williams.

require_relative '../../lib/async'
require 'console'

Async do |task|
	while true
		task.async do
			Console.info("Child running.")
			sleep 0.1
		end.wait
	end
end

# ruby3-tcp-server-mini-benchmark$ ruby loop.rb async-scheduler.rb 
# spawn
# /usr/bin/wrk -t1 -c1 -d1s http://localhost:9090
# waiting for process to die
# spawn
# /usr/bin/wrk -t1 -c1 -d1s http://localhost:9090
# waiting for process to die
# ^Cloop.rb:24:in `waitpid': Interrupt
# 	from loop.rb:24:in `block in <main>'
# 	from loop.rb:15:in `loop'
# 	from loop.rb:15:in `<main>'
# /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/list.rb:250:in `initialize': Interrupt
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/list.rb:298:in `new'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/list.rb:298:in `each'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/list.rb:176:in `each'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/node.rb:240:in `terminate'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/scheduler.rb:52:in `close'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/scheduler.rb:46:in `ensure in scheduler_close'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/scheduler.rb:46:in `scheduler_close'
# /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/node.rb:110:in `transient?': SIGHUP (SignalException)
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/node.rb:47:in `removed'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/list.rb:132:in `remove!'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/list.rb:121:in `remove'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/node.rb:182:in `remove_child'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/node.rb:197:in `consume'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/task.rb:287:in `finish!'
# 	from /home/jsaak/.gem/ruby/3.2.1/gems/async-2.6.1/lib/async/task.rb:360:in `block in schedule'

