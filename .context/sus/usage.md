# Using Sus Testing Framework

## Overview

Sus is a modern Ruby testing framework that provides a clean, BDD-style syntax for writing tests. It's designed to be fast, simple, and expressive.

## Basic Structure

Here is an example structure for testing with Sus - the actual structure may vary based on your gem's organization, but aside from the `lib/` directory, sus expects the following structure:

```
my-gem/
├── config/
│   └── sus.rb                     # Sus configuration file
├── lib/
│   ├── my_gem.rb
│   └── my_gem/
│       └── my_thing.rb
├── fixtures/
│   └── my_gem/
│       └── a_thing.rb               # Provides MyGem::AThing shared context
└── test/
    ├── my_gem.rb                    # Tests MyGem
    └── my_gem/
        └── my_thing.rb              # Tests MyGem::MyThing
```

### Configuration File

Create `config/sus.rb`:

```ruby
# frozen_string_literal: true

# Use the covered gem for test coverage reporting:
require 'covered/sus'
include Covered::Sus

def before_tests(assertions, output: self.output)
	# Starts the clock and sets up the test environment:
	super
end

def after_tests(assertions, output: self.output)
	# Stops the clock and prints the test results:
	super
end
```

### Fixtures Files

`fixtures/` gets added to the `$LOAD_PATH` automatically, so you can require files from there without needing to specify the full path.

### Test Files

Sus runs all Ruby files in the `test/` directory by default. But you can also create tests in any file, and run them with the `sus my_tests.rb` command.

## Basic Syntax

```ruby
# frozen_string_literal: true

describe MyThing do
	let(:my_thing) {subject.new}
	
	with "#my_method" do
		it "does something" do
			expect(my_thing.my_method).to be == 42
		end
	end
end
```

### `describe` - Test Groups

Use `describe` to group related tests:

```ruby
describe MyThing do
	# The subject will be whatever is described:
	let(:my_thing) {subject.new}
end
```

### `it` - Individual Tests

Use `it` to define individual test cases:

```ruby
it "returns the expected value" do
	expect(result).to be == "expected"
end
```

You can use `it` blocks at the top level or within `describe` or `with` blocks.

### `with` - Context Blocks

Use `with` to create context-specific test groups:

```ruby
with "valid input" do
	let(:input) {"valid input"}
	it "succeeds" do
		expect{my_thing.process(input)}.not.to raise_exception
	end
end

# Non-lazy state can be provided as keyword arguments:
with "invalid input", input: nil do
	it "raises an error" do
		expect{my_thing.process(input)}.to raise_exception(ArgumentError)
	end
end
```

When testing methods, use `with` to specify the method being tested:

```ruby
with "#my_method" do
	it "results a value" do
		expect(my_thing.method).to be == 42
	end
end

with ".my_class_method" do
	it "returns a value" do
		expect(MyThing.class_method).to be == "class value"
	end
end
```

### `let` - Lazy Variables

Use `let` to define variables that are evaluated when first accessed:

```ruby
let(:helper) {subject.new}
let(:test_data) {"test value"}

it "uses the helper" do
	expect(helper.process(test_data)).to be_truthy
end
```

### `before` and `after` - Setup/Teardown

Use `before` and `after` for setup and teardown logic:

```ruby
before do
	# Setup logic.
end

after do
	# Cleanup logic.
end
```

Error handling in `after` allows you to perform cleanup even if the test fails with an exception (not a test failure).

```ruby
after do |error = nil|
	if error
		# The state of the test is unknown, so you may want to forcefully kill processes or clean up resources.
		Process.kill(:KILL, @child_pid)
	else
		# Normal cleanup logic.
		Process.kill(:TERM, @child_pid)
	end
	
	Process.waitpid(@child_pid)
end
```

### `around` - Setup/Teardown

Use `around` for setup and teardown logic:

```ruby
around do |&block|
	# Setup logic.
	super() do
		# Run the test.
		block.call
	end
ensure
	# Cleanup logic.
end
```

Invoking `super()` calls any parent `around` block, allowing you to chain setup and teardown logic.

## Assertions

### Basic Assertions

```ruby
expect(value).to be == expected
exepct(value).to be >= 10
expect(value).to be <= 100
expect(value).to be > 0
expect(value).to be < 1000
expect(value).to be_truthy
expect(value).to be_falsey
expect(value).to be_nil
expect(value).to be_equal(another_value)
expect(value).to be_a(Class)
```

### Strings

```ruby
expect(string).to be(:start_with?, "prefix")
expect(string).to be(:end_with?, "suffix")
expect(string).to be(:match?, /pattern/)
expect(string).to be(:include?, "substring")
```

### Ranges and Tolerance

```ruby
expect(value).to be_within(0.1).of(5.0)
expect(value).to be_within(5).percent_of(100)
```

### Method Calls

To call methods on the expected object:

```ruby
expect(array).to be(:include?, "value")
expect(string).to be(:start_with?, "prefix")
expect(object).to be(:respond_to?, :method_name)
```

### Collection Assertions

```ruby
expect(array).to have_attributes(length: be == 1)
expect(array).to have_value(be > 1)

expect(hash).to have_keys(:key1, "key2")
expect(hash).to have_keys(key1: be == 1, "key2" => be == 2)
```

### Attribute Testing

```ruby
expect(user).to have_attributes(
  name: be == "John",
  age: be >= 18,
  email: be(:include?, "@")
)
```

### Exception Assertions

```ruby
expect do
	risky_operation
end.to raise_exception(RuntimeError, message: be =~ /expected error message/)
```

## Combining Predicates

Predicates can be nested.

```ruby
expect(user).to have_attributes(
	name: have_attributes(
		first: be == "John",
		last: be == "Doe"
	),
	comments: have_value(be =~ /test comment/),
	created_at: be_within(1.minute).of(Time.now)
)
```

### Logical Combinations

```ruby
expect(value).to (be > 10).and(be < 20)
expect(value).to be_a(String).or(be_a(Symbol), be_a(Integer))
```

### Custom Predicates

You can create custom predicates for more complex assertions:

```ruby
def be_small_prime
	(be == 2).or(be == 3, be == 5, be == 7)
end
```

## Block Expectations

### Testing Blocks

```ruby
expect{operation}.to raise_exception(Error)
expect{operation}.to have_duration(be < 1.0)
```

### Performance Testing

You should generally avoid testing performance in unit tests, as it will be highly unstable and dependent on the environment. However, if you need to test performance, you can use:

```ruby
expect{slow_operation}.to have_duration(be < 2.0)
expect{fast_operation}.to have_duration(be < 0.1)
```

- For less unsable performance tests, you can use the `sus-fixtures-time` gem which tries to compensate for the environment by measuring execution time.

- For benchmarking, you can use the `sus-fixtures-benchmark` gem which measures a block of code multiple times and reports the execution time.

## File Operations

### Temporary Directories

Use `Dir.mktmpdir` for isolated test environments:

```ruby
around do |block|
	Dir.mktmpdir do |root|
		@root = root
		block.call
	end
end

let(:test_path) {File.join(@root, "test.txt")}

it "can create a file" do
	File.write(test_path, "content")
	expect(File).to be(:exist?, test_path)
end
```

## Test Output

In general, tests should not produce output unless there is an error or failure.

### Informational Output

You can use `inform` to print informational messages during tests:

```ruby
it "logs an informational message" do
	rate = copy_data(source, destination)
	inform "Copied data at #{rate}MB/s"
	expect(rate).to be > 0
end
```

This can be useful for debugging or providing context during test runs.

### Console Output

The `sus-fixtures-console` gem provides a way to surpress and capture console output during tests. If you are using code which generates console output, you can use this gem to capture it and assert on it.

## Running Tests

```bash
# Run all tests
bundle exec sus

# Run specific test file
bundle exec sus test/specific_test.rb
```

## Best Practices

1. **Use real objects** instead of mocks when possible.
2. **Dependency injection** for testability.
3. **Isolatae mutable state** using temporary directories.
4. **Clear test descriptions** that explain the behavior.
5. **Group tests** with `describe` (classes) and `with` for better organization.
6. **Keep tests simple** and focused on one behavior.
