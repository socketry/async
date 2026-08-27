
require 'net/http'

run ->(env) do
	term = "ruby"
	
	response = Net::HTTP.get(URI "https://www.google.com/search?q=#{term}")
	
	count = response.scan(term).size
	
	[200, [], ["Found #{count} times.\n"]]
end
