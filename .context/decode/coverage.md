# Documentation Coverage

This guide explains how to test and monitor documentation coverage in your Ruby projects using the Decode gem's built-in bake tasks.

## Available Bake Tasks

The Decode gem provides several bake tasks for analyzing your codebase:

- `bake decode:index:coverage` - Check documentation coverage.
- `bake decode:index:symbols` - List all symbols in the codebase.
- `bake decode:index:documentation` - Extract all documentation.

## Checking Documentation Coverage

### Basic Coverage Check

```bash
# Check coverage for the lib directory:
bake decode:index:coverage lib

# Check coverage for a specific directory:
bake decode:index:coverage app/models
```

### Understanding Coverage Output

When you run the coverage command, you'll see output like:

```
15 definitions have documentation, out of 20 public definitions.

Missing documentation for:
- MyGem::SomeClass#method_name
- MyGem::AnotherClass
- MyGem::Utility.helper_method
```

The coverage check:
- **Counts only public definitions** (public methods, classes, modules).
- **Reports the ratio** of documented vs total public definitions.
- **Lists missing documentation** by qualified name.
- **Fails with an error** if coverage is incomplete.

### What Counts as "Documented"

A definition is considered documented if it has:
- Any comment preceding it.
- Documentation pragmas (like `@parameter`, `@returns`).
- A `@namespace` pragma (for organizational modules).

```ruby
# Represents a user in the system.
class MyClass
end

# @namespace
module OrganizationalModule
  # Contains helper functionality.
end

# Process user data and return formatted results.
# @parameter name [String] The user's name.
# @returns [Boolean] Success status.
def process(name)
  # Validation logic here:
  return false if name.empty?
  
  # Processing logic:
  true
end

class UndocumentedClass
end
```

## Analyzing Symbols

### List All Symbols

```bash
# See the structure of your codebase
bake decode:index:symbols lib
```

This shows the hierarchical structure of your code:

```
[] -> []
["MyGem"] -> [#<Decode::Language::Ruby::Module:...>]
  MyGem
["MyGem", "User"] -> [#<Decode::Language::Ruby::Class:...>]
    MyGem::User
["MyGem", "User", "initialize"] -> [#<Decode::Language::Ruby::Method:...>]
      MyGem::User#initialize
```

### Extract Documentation

```bash
# Extract all documentation from your codebase
bake decode:index:documentation lib
```

This outputs formatted documentation for all documented definitions:

~~~markdown
## `MyGem::User#initialize`

Initialize a new user with the given email address.

## `MyGem::User#authenticate`

Authenticate the user with a password.
Returns true if authentication is successful.
~~~

## Achieving 100% Coverage

### Strategy for Complete Coverage

1. **Document all public APIs**
   ```ruby
   # Represents a user management system.
   class User
     # @attribute [String] The user's email address.
     attr_reader :email
     
     # Initialize a new user.
     # @parameter email [String] The user's email address.
     def initialize(email)
       # Store the email address:
       @email = email
     end
   end
   ```

2. **Use @namespace for organizational modules**
   ```ruby
   # @namespace
   module MyGem
     # Contains the main functionality.
   end
   ```

3. **Document edge cases**
   ```ruby
   # @private
   def internal_helper
     # Internal implementation details.
   end
   ```

### Common Coverage Issues

**Issue: Missing namespace documentation**
```ruby
# This module has no documentation and will show as missing coverage:
module MyGem
end

# Solution: Add @namespace pragma:
# @namespace
module MyGem
  # Provides core functionality.
end
```

**Issue: Undocumented methods**

Problem: Methods without any comments will show as missing coverage:
```ruby
def process_data
  # Implementation here
end
```

Solution: Add description and pragmas:
```ruby
# Process the input data and return results.
# @parameter data [Hash] Input data to process.
# @returns [Array] Processed results.
def process_data(data)
  # Process the input:
  results = data.map { |item| transform(item) }
  
  # Return processed results:
  results
end
```

**Issue: Missing attr documentation**

Problem: Attributes without documentation will show as missing coverage:
```ruby
attr_reader :name
```

Solution: Document with @attribute pragma:
```ruby
# @attribute [String] The user's full name.
attr_reader :name
```

## Integrating into CI/CD

### GitHub Actions Example

```yaml
name: Documentation Coverage

on: [push, pull_request]

jobs:
  docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Check documentation coverage
        run: bake decode:index:coverage lib
```

### Rake Task Integration

Add to your `Rakefile`:

```ruby
require 'decode'

desc "Check documentation coverage"
task :doc_coverage do
  system("bake decode:index:coverage lib") || exit(1)
end

task default: [:test, :doc_coverage]
```

## Monitoring Coverage Over Time

### Generate Coverage Reports

```ruby
# Generate a coverage percentage for the specified directory.
# @parameter root [String] The root directory to analyze.
# @returns [Float] The coverage percentage.
def coverage_percentage(root)
  index = Decode::Index.new
  index.update(Dir.glob(File.join(root, "**/*.rb")))
  
  documented = 0
  total = 0
  
  index.trie.traverse do |path, node, descend|
    node.values&.each do |definition|
      if definition.public?
        total += 1
        documented += 1 if definition.comments&.any?
      end
    end
    descend.call if node.values.nil?
  end
  
  (documented.to_f / total * 100).round(2)
end

puts "Coverage: #{coverage_percentage('lib')}%"
```

### Exclude Patterns

If you need to exclude certain files from coverage:

```ruby
# Custom coverage script with exclusions.
paths = Dir.glob("lib/**/*.rb").reject do |path|
  # Exclude vendor files and test files:
  path.include?('vendor/') || path.end_with?('_test.rb')
end

index = Decode::Index.new
index.update(paths)
# ... continue with coverage analysis
```

## Best Practices

1. **Run coverage checks regularly** - Include in your CI pipeline
2. **Set coverage targets** - Aim for 100% coverage of public APIs
3. **Document incrementally** - Add documentation as you write code
4. **Use meaningful descriptions** - Don't just add empty comments
5. **Leverage @namespace** - For modules that only serve as containers
6. **Review coverage reports** - Use the missing documentation list to prioritize

## Troubleshooting

### Common Error Messages

**"Insufficient documentation!"**
- Some public definitions are missing documentation
- Check the list of missing items and add appropriate comments

**No output from coverage command**
- Verify the path exists: `bake decode:index:coverage lib`
- Check that Ruby files exist in the specified directory

**Coverage shows 0/0 definitions**
- The directory might not contain any Ruby files
- Try a different path or check your file extensions

### Debug Coverage Issues

```bash
# First, see what symbols are being detected
bake decode:index:symbols lib

# Then check what documentation exists
bake decode:index:documentation lib

# Finally, run coverage to see what's missing
bake decode:index:coverage lib
```

This workflow helps you understand what the tool is detecting and why certain items might be missing documentation.
