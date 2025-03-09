
require 'net/http'

run ->(env) do
	response = Net::HTTP.get(URI "https://www.google.com/search?q=ruby")
	
	count = response.scan("ruby").count
	
	[200, [], ["Found ruby #{count} times!"]]
end
