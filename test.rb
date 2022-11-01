#!/usr/bin/env ruby

require_relative 'lib/async'

p pid: Process.pid

class Server
  def initialize
    @running = false
  end

  def stopping?
    !@running
  end

  def stop(&after_shutdown)
    @after_shutdown = after_shutdown if after_shutdown
    @running = false
  end

  def start(task: Async::Task.current)
    task.async do |task|
      @running = true

      while @running
        run_once
        sleep 0.1
      end

      @after_shutdown.call if @after_shutdown
    end
  end

  def run_once
    print '.'
  end
end

Async do |task|
  server = Server.new

  Signal.trap(:INT) do
    puts "Got INT"
    abort 'Aborting' if server.stopping? # abort on second ^C

    server.stop do
      puts "Server shut down. Stopping task."
      task.stop
    end
  end

  server.start

  task.async do
    puts "sleeping #1"
    sleep
  end

  # NOTE: Hangs only if this second task is added
  task.async do
    puts "sleeping #2"
    sleep
  end
end

puts 'Done'
