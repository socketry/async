# Uses the same acquire/release flow as Sequel::ThreadedConnectionPool
class ResourcePool
  class TimeoutError < StandardError; end

  def initialize(pool_size:, timeout:)
    @available_resources = pool_size.times.map { |n| "resource-#{n}" }
    @timeout = timeout
    @mutex = Mutex.new
    @waiter = ConditionVariable.new
  end

  def with_resource
    resource = acquire
    yield resource
  ensure
    if resource
      release(resource)
    end
  end

  private

  def acquire
    if resource = sync_next_available
      Logger.debug('Pool: Acquired resource without waiting')
      return resource
    end

    timeout = @timeout
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    @mutex.synchronize do
      Logger.debug('Pool: Waiting')
      @waiter.wait(@mutex, timeout)
      if resource = next_available
        Logger.debug('Pool: Acquired resource after waiting')
        return resource
      end
    end

    until resource = sync_next_available
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      
      if elapsed > timeout
        raise TimeoutError, "Unable to acquire resource after #{elapsed} seconds"
      end

      # We get here when the resource was released and this fiber was unblocked by the signal,
      # but the resource was immediately re-acquired by the fiber that sent the signal before
      # this fiber could be resumed. Effectively a race condition.
      @mutex.synchronize do
        Logger.debug('Pool: Woken by signal but resource unavailable. Waiting again.')
        @waiter.wait(@mutex, timeout - elapsed)
        if resource = next_available
          Logger.debug('Pool: Acquired resource after multiple waits')
          return resource
        end
      end
    end

    Logger.debug('Pool: Acquired resource after waiting')
    resource
  end

  def release(resource)
    @mutex.synchronize do
      @available_resources << resource
      Logger.debug('Pool: Released resource. Signaling.')
      @waiter.signal
    end

    sleep(0)
  end

  def sync_next_available
    @mutex.synchronize do
      next_available
    end
  end

  def next_available
    @available_resources.pop
  end
end
