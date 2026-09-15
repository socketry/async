require_relative '../../../lib/async'
require_relative 'resource_pool'

POOL = ResourcePool.new(pool_size: 1, timeout: 0.1)
WORKER_COUNT = 3
MAX_TEST_DURATION = 2.0
LOG_COLORS = [:light_blue, :light_magenta, :light_green, :light_red, :light_cyan, :light_yellow,
              :blue, :magenta, :green, :red, :cyan, :yellow]

class Logger
  def self.debug(message)
    task = Async::Task.current
    fiber = Fiber.current
    color = Thread.current[:log_color]
    Console.logger.info(task, message)
  end
end

Async do
  clock = Async::Clock.new
  clock.start!

  WORKER_COUNT.times do |n|
    Async(annotation: "worker-#{n}") do
      Thread.current[:log_color] = LOG_COLORS[n]

      begin
        while clock.total < MAX_TEST_DURATION do
          POOL.with_resource do
            Logger.debug('Sleep with resource #1')
            sleep(0.001) # simulates a DB call
          end

          POOL.with_resource do
            Logger.debug('Sleep with resource #2')
            sleep(0.001) # simulates a DB call
          end

          Logger.debug('Sleep without resource')
          sleep(0.001) # simulates some other IO
        end
      rescue ResourcePool::TimeoutError => e
        Logger.debug("Timed out. Aborting test after #{clock.total} seconds")
        puts "#{e.class} #{e.message}"
        puts e.backtrace
        STDOUT.flush
        Kernel.exit!
      end
    end
  end
end