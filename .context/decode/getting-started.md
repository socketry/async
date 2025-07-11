# Getting Started with Decode

The Decode gem provides programmatic access to Ruby code structure and metadata. It can parse Ruby files and extract definitions, comments, and documentation pragmas, enabling code analysis, documentation generation, and other programmatic manipulations of Ruby codebases.

## Installation

Add to your Gemfile:

```ruby
gem 'decode'
```

Or install directly:

```bash
bundle add decode
```

## Basic Usage

### Analyzing a Ruby File

```ruby
require 'decode'

# Create a source object:
source = Decode::Source.new('lib/my_class.rb', Decode::Language::Ruby.new)

# Extract definitions (classes, methods, etc.):
definitions = source.definitions.to_a

definitions.each do |definition|
  puts "#{definition.name}: #{definition.short_form}"
end
```

### Extracting Documentation

```ruby
# Get segments (blocks of comments + code):
segments = source.segments.to_a

segments.each do |segment|
  puts "Comments: #{segment.comments.join(' ')}"
  puts "Code: #{segment.code}"
end
```

### Checking Documentation Coverage

```ruby
# Check which definitions have documentation:
definitions.each do |definition|
  status = definition.comments.any? ? 'documented' : 'missing docs'
  puts "#{definition.name}: #{status}"
end
```

## Working with Documentation Pragmas

The Decode gem understands structured documentation pragmas:

```ruby
# This will be parsed and structured:
source_code = <<~RUBY
  # Represents a user in the system.
  class User
    # @attribute [String] The user's email address.
    attr_reader :email
    
    # Initialize a new user.
    # @parameter email [String] The user's email address.
    # @parameter options [Hash] Additional options.
    # @option :active [Boolean] Whether the account is active.
    # @raises [ArgumentError] If email is invalid.
    def initialize(email, options = {})
      # Validate the email format:
      raise ArgumentError, "Invalid email" if email.empty?
      
      # Set instance variables:
      @email = email
      @active = options.fetch(:active, true)
    end
  end
RUBY

# Parse and analyze:
result = Decode::Language::Ruby.new.parser.parse_source(source_code)
definitions = Decode::Language::Ruby.new.parser.definitions_for(source_code).to_a

definitions.each do |definition|
  puts "#{definition.name}: #{definition.comments.join(' ')}"
end
```

## Common Use Cases

### 1. Code Analysis and Metrics

```ruby
# Analyze a codebase and return metrics.
# @parameter file_path [String] Path to the Ruby file to analyze.
def analyze_codebase(file_path)
  source = Decode::Source.new(file_path, Decode::Language::Ruby.new)
  definitions = source.definitions.to_a
  
  # Count different definition types:
  classes = definitions.count { |d| d.is_a?(Decode::Language::Ruby::Class) }
  methods = definitions.count { |d| d.is_a?(Decode::Language::Ruby::Method) }
  modules = definitions.count { |d| d.is_a?(Decode::Language::Ruby::Module) }
  
  puts "Classes: #{classes}, Methods: #{methods}, Modules: #{modules}"
end
```

### 2. Documentation Coverage Reports

```ruby
# Calculate documentation coverage for a file.
# @parameter file_path [String] Path to the Ruby file to analyze.
def documentation_coverage(file_path)
  source = Decode::Source.new(file_path, Decode::Language::Ruby.new)
  definitions = source.definitions.to_a
  
  # Calculate coverage statistics:
  total = definitions.count
  documented = definitions.count { |d| d.comments.any? }
  
  puts "Coverage: #{documented}/#{total} (#{(documented.to_f / total * 100).round(1)}%)"
end
```

### 3. Extracting API Information

```ruby
# Extract API information from a Ruby file.
# @parameter file_path [String] Path to the Ruby file to analyze.
def extract_api_info(file_path)
  source = Decode::Source.new(file_path, Decode::Language::Ruby.new)
  definitions = source.definitions.to_a
  
  # Get public methods only:
  public_methods = definitions.select do |definition|
    definition.is_a?(Decode::Language::Ruby::Method) && 
    definition.visibility == :public
  end
  
  public_methods.each do |method|
    puts "#{method.long_form}"
    puts "  Comments: #{method.comments.join(' ')}" if method.comments.any?
  end
end
```

### 4. Code Structure Analysis

```ruby
# Analyze the structure of Ruby files in a directory.
# @parameter directory [String] Path to the directory to analyze.
def analyze_structure(directory)
  Dir.glob("#{directory}/**/*.rb").each do |file|
    source = Decode::Source.new(file, Decode::Language::Ruby.new)
    definitions = source.definitions.to_a
    
    # Find nested classes and modules:
    nested = definitions.select { |d| d.parent }
    
    if nested.any?
      puts "#{file}:"
      nested.each do |definition|
        puts "  #{definition.qualified_name}"
      end
    end
  end
end
```

### 5. Finding Undocumented Code

```ruby
# Find undocumented code in a directory.
# @parameter directory [String] Path to the directory to analyze.
def find_undocumented(directory)
  Dir.glob("#{directory}/**/*.rb").each do |file|
    source = Decode::Source.new(file, Decode::Language::Ruby.new)
    definitions = source.definitions.to_a
    
    # Filter for undocumented public definitions:
    undocumented = definitions.select { |d| d.comments.empty? && d.visibility == :public }
    
    if undocumented.any?
      puts "#{file}:"
      undocumented.each do |definition|
        puts "  - #{definition.short_form}"
      end
    end
  end
end
```

## Advanced Features

### Using the Index

```ruby
# Create an index for multiple files:
index = Decode::Index.new
index.update(Dir.glob("lib/**/*.rb"))

# Search through the index:
index.trie.traverse do |path, node, descend|
  if node.values
    node.values.each do |definition|
      puts "#{path.join('::')} - #{definition.short_form}"
    end
  end
  descend.call
end
```

### Custom Language Support

```ruby
# The decode gem is extensible:
language = Decode::Language::Generic.new("custom")
# You can implement your own parser for other languages:
```

## Tips for Effective Usage

1. **Use structured pragmas** - They help tools understand your code better.
2. **Leverage programmatic access** - Build tools that analyze and manipulate code.
3. **Use @namespace** - For organizational modules to achieve complete coverage.
4. **Analyze code patterns** - Use decode to understand codebase structure.
5. **Build automation** - Use decode in CI/CD pipelines for code quality checks.

## Next Steps

- See [Ruby Documentation](ruby-documentation.md) for complete pragma reference.
- Check out [Documentation Coverage](coverage.md) for coverage monitoring.
- Use decode to build code analysis tools for your projects.
- Integrate decode into your development workflow and CI/CD pipelines.
