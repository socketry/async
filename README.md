# Async

Async is a composable asynchronous I/O framework for Ruby based on [nio4r] and [timers].

[timers]: https://github.com/socketry/timers
[nio4r]: https://github.com/socketry/nio4r

[![Build Status](https://secure.travis-ci.org/socketry/async.svg)](http://travis-ci.org/socketry/async)
[![Code Climate](https://codeclimate.com/github/socketry/async.svg)](https://codeclimate.com/github/socketry/async)
[![Coverage Status](https://coveralls.io/repos/socketry/async/badge.svg)](https://coveralls.io/r/socketry/async)

## Motivation

Several years ago, I was hosting websites on a server in my garage. Back then, my ADSL modem was very basic, and I wanted to have a DNS server which would resolve to an internal IP address when the domain itself resolved to my public IP. Thus was born [RubyDNS]. This project [was originally built on](https://github.com/ioquatix/rubydns/tree/v0.8.5) top of [EventMachine], but a lack of support for [IPv6 at the time](https://github.com/ioquatix/rubydns/issues/45) and [other problems](https://github.com/ioquatix/rubydns/issues/14), meant that I started looking for other options. Around that time [Celluloid] was picking up steam. I had not encountered actors before and I wanted to learn more about it. So, [I reimplemented RubyDNS on top of Celluloid](https://github.com/ioquatix/rubydns/tree/v0.9.0) and this eventually became the first stable release.

Moving forward, I refactored the internals of RubyDNS into [Celluloid::DNS]. This rewrite helped solidify the design of RubyDNS and to a certain extent it works. However, [unfixed bugs and design problems](https://github.com/celluloid/celluloid/pull/710) in Celluloid meant that RubyDNS 2.0 was delayed by almost 2 years. I wasn't happy releasing things with known bugs and problems. Anyway, a lot of discussion and thinking, I decided to build a small event reactor using [nio4r] and [timers], the core parts of [Celluloid::IO] which made it work so well.

[Celluloid]: https://github.com/celluloid/celluloid
[Celluloid::IO]: https://github.com/celluloid/celluloid-io
[Celluloid::DNS]: https://github.com/celluloid/celluloid-dns
[EventMachine]: https://github.com/eventmachine/eventmachine
[RubyDNS]: https://github.com/ioquatix/rubydns

## Installation

Add this line to your application's Gemfile:

```ruby
gem "async"
```

And then execute:

	$ bundle

Or install it yourself as:

	$ gem install async

## Usage

Implementing an asynchronous client/server is easy:

```ruby
#!/usr/bin/env ruby

require 'async'
require 'async/tcp_socket'

def echo_server
  Async::Reactor.run do |task|
    # This is a synchronous block within the current task:
    task.with(TCPServer.new('localhost', 9000)) do |server|
      
      # This is an asynchronous block within the current reactor:
      task.reactor.with(server.accept) do |client|
        data = client.read(512)
        
        task.sleep(rand)
        
        client.write(data)
      end while true
    end
  end
end

def echo_client(data)
  Async::Reactor.run do |task|
    Async::TCPServer.connect('localhost', 9000) do |socket|
      socket.write(data)
      puts "echo_client: #{socket.read(512)}"
    end
  end
end

Async::Reactor.run do
  # Start the echo server:
  server = echo_server
  
  5.times.collect do |i|
    echo_client("Hello World #{i}")
  end.each(&:wait) # Wait until all clients are finished.
  
  # Terminate the server and all tasks created within it's async scope:
  server.stop
end
```

## Supported Ruby Versions

This library aims to support and is [tested against][travis] the following Ruby
versions:

* Ruby 2.0+
* JRuby 9.1.6.0+

If something doesn't work on one of these versions, it's a bug.

This library may inadvertently work (or seem to work) on other Ruby versions,
however support will only be provided for the versions listed above.

If you would like this library to support another Ruby version or
implementation, you may volunteer to be a maintainer. Being a maintainer
entails making sure all tests run and pass on that implementation. When
something breaks on your implementation, you will be responsible for providing
patches in a timely fashion. If critical issues for a particular implementation
exist at the time of a major release, support for that Ruby version may be
dropped.

[travis]: http://travis-ci.org/socketry/async

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## See Also

- [async-dns](https://github.com/socketry/async-dns) — Asynchronous DNS resolver and server.
- [rubydns](https://github.com/ioquatix/rubydns) — A easy to use Ruby DNS server.

## License

Released under the MIT license.

Copyright, 2017, by [Samuel G. D. Williams](http://www.codeotaku.com/samuel-williams).

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
