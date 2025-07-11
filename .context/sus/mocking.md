# Mocking

There are two types of mocking in sus: `receive` and `mock`. The `receive` matcher is a subset of full mocking and is used to set expectations on method calls, while `mock` can be used to replace method implementations or set up more complex behavior.

Mocking non-local objects permanently changes the object's ancestors, so it should be used with care. For local objects, you can use `let` to define the object and then mock it.

Sus does not support the concept of test doubles, but you can use `receive` and `mock` to achieve similar functionality.

## Method Call Expectations

The `receive(:method)` expectation is used to set up an expectation that a method will be called on an object. You can also specify arguments and return values. However, `receive` is not sequenced, meaning it does not enforce the order of method calls. If you need to enforce the order, use `mock` instead.

```ruby
describe MyThing do
	let(:my_thing) {subject.new}
	
	it "calls the expected method" do
		expect(my_thing).to receive(:my_method)
		
		expect(my_thing.my_method).to be == 42
	end
end
```

### With Arguments

```ruby
it "calls the method with arguments" do
	expect(object).to receive(:method_name).with(arg1, arg2)
	# or .with_arguments(be == [arg1, arg2])
	# or .with_options(be == {option1: value1, option2: value2})
	# or .with_block
	
	object.method_name(arg1, arg2)
end
```

### Returning Values

```ruby
it "returns a value" do
	expect(object).to receive(:method_name).and_return("expected value")
	result = object.method_name
	expect(result).to be == "expected value"
end
```

### Raising Exceptions

```ruby
it "raises an exception" do
	expect(object).to receive(:method_name).and_raise(StandardError, "error message")
	
	expect{object.method_name}.to raise_exception(StandardError, message: "error message")
end
```

### Multiple Calls

```ruby
it "calls the method multiple times" do
	expect(object).to receive(:method_name).twice.and_return("result")
	# or .with_call_count(be == 2)
	expect(object.method_name).to be == "result"
	expect(object.method_name).to be == "result"
end
```

## Mock Objects

Mock objects are used to replace method implementations or set up complex behavior. They can be used to intercept method calls, modify arguments, and control the flow of execution. They are thread-local, meaning they only affect the current thread, therefore are not suitable for use in tests that have multiple threads.

```ruby
describe ApiClient do
	let(:http_client) {Object.new}
	let(:client) {ApiClient.new(http_client)}
	let(:users) {["Alice", "Bob"]}
	
	it "makes GET requests" do
		mock(http_client) do |mock|
			mock.replace(:get) do |url, headers: {}|
				expect(url).to be == "/api/users"
				expect(headers).to be == {"accept" => "application/json"}
				users.to_json
			end
			
			# or mock.before {|...| ...}
			# or mock.after {|...| ...}
			# or mock.wrap(:new) {|original, ...| original.call(...)}
		end
		
		expect(client.fetch_users).to be == users
	end
end
```
