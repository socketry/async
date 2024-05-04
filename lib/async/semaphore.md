A synchronization primitive, which limits access to a given resource, such as a limited number of database connections, open files, or network connections.

## Example

~~~ ruby
require 'async'
require 'async/semaphore'
require 'net/http'

Sync do
	# Only allow two concurrent tasks at a time:
	semaphore = Async::Semaphore.new(2)
	
	# Generate an array of 10 numbers:
	terms = ['ruby', 'python', 'go', 'java', 'c++'] 
	
	# Search for the terms:
	terms.each do |term|
		semaphore.async do |task|
			Console.info("Searching for #{term}...")
			response = Net::HTTP.get(URI "https://www.google.com/search?q=#{term}")
			Console.info("Got response #{response.size} bytes.")
		end
	end
end
~~~

### Output

~~~
0.0s     info: Searching for ruby... [ec=0x3c] [pid=50523]
0.04s     info: Searching for python... [ec=0x21c] [pid=50523]
1.7s     info: Got response 182435 bytes. [ec=0x3c] [pid=50523]
1.71s     info: Searching for go... [ec=0x834] [pid=50523]
3.0s     info: Got response 204854 bytes. [ec=0x21c] [pid=50523]
3.0s     info: Searching for java... [ec=0xf64] [pid=50523]
4.32s     info: Got response 103235 bytes. [ec=0x834] [pid=50523]
4.32s     info: Searching for c++... [ec=0x12d4] [pid=50523]
4.65s     info: Got response 109697 bytes. [ec=0xf64] [pid=50523]
6.64s     info: Got response 87249 bytes. [ec=0x12d4] [pid=50523]
~~~
