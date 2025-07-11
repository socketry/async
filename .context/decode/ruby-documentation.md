# Ruby Documentation

This guide covers documentation practices and pragmas supported by the Decode gem for documenting Ruby code. These pragmas provide structured documentation that can be parsed and used to generate API documentation and achieve complete documentation coverage.

## Documentation Guidelines

### Writing Style and Format

#### Definition Documentation

- **Full sentences**: All documentation for definitions (classes, modules, methods) should be written as complete sentences with proper grammar and punctuation.
- **Class documentation**: Documentation for classes should generally start with "Represents a ..." to clearly indicate what the class models or encapsulates.
- **Method documentation**: Should clearly describe what the method does, not how it does it.
- **Markdown format**: All documentation comments are written in Markdown format, allowing for rich formatting including lists, emphasis, code blocks, and links.

#### Inline Code Comments

- **Explanatory comments**: Comments within methods that explain specific lines or sections of code should end with a colon `:` to distinguish them from definition documentation.
- **Purpose**: These comments explain the reasoning behind specific implementation details.

#### Links and Code Formatting

- **Curly braces `{}`**: Use curly braces to create links to other methods, classes, or modules. The Decode gem uses `@index.lookup(text)` to resolve these references.
	- **Absolute references**: `{Decode::Index#lookup}` - Links to a specific method in a specific class
	- **Relative references**: `{lookup}` - Links to a method in the current scope or class
	- **Class references**: `{User}` - Links to a class or module
- **Backticks**: Use backticks for code formatting of symbols, values, method names, and technical terms that should appear in monospace font.
	- **Symbols**: `:admin`, `:user`, `:guest`
	- **Values**: `true`, `false`, `nil`
	- **Technical terms**: `attr_*`, `catch`/`throw`
	- **Code expressions**: `**options`

#### Examples

```ruby
# Represents a user account in the system.
class User
	# @attribute [String] The user's email address.
	attr_reader :email
	
	# Initialize a new user account.
	# @parameter email [String] The user's email address.
	# @raises [ArgumentError] If email is invalid.
	def initialize(email)
		# Validate email format before assignment:
		raise ArgumentError, "Invalid email format" unless email.match?(/\A[^@\s]+@[^@\s]+\z/)
		
		# Store the normalized email:
		@email = email.downcase.strip
	end
	
	# Authenticate the user with the provided password.
	# @parameter password [String] The password to verify.
	# @returns [Boolean] True if authentication succeeds.
	def authenticate(password)
		# Hash the password for comparison:
		hashed = hash_password(password)
		
		# Compare against stored hash:
		hashed == @password_hash
	end
	
	# Deactivate the user account.
	# This method sets the user's status to inactive. Use this instead of
	# the deprecated {disable!} method. The account status can be checked
	# using `active?` or by examining the `:active` attribute.
	# @returns [Boolean] Returns `true` if deactivation was successful.
	def deactivate!
		@active = false
		true
	end
end

# Represents a collection of users with search capabilities.
class UserCollection
	# Find users matching the given criteria.
	# @parameter criteria [Hash] Search parameters.
	# @returns [Array(User)] Matching users.
	def find(**criteria)
		# Start with all users:
		results = @users.dup
		
		# Apply each filter criterion:
		criteria.each do |key, value|
			results = filter_by(results, key, value)
		end
		
		results
	end
end
```

**Key formatting examples from above:**
- `{disable!}` - Creates a link to the `disable!` method (relative reference)
- `active?` - Formats the method name in monospace (backticks for code formatting)
- `:active` - Formats the symbol in monospace (backticks for code formatting)
- `true` - Formats the boolean value in monospace (backticks for code formatting)

### Best Practices

1. **Be Consistent**: Use the same format for similar types of documentation.
2. **Include Types**: Always specify types for parameters, returns, and attributes.
3. **Be Descriptive**: Provide clear, actionable descriptions.
4. **Document Exceptions**: Always document what exceptions might be raised.
5. **Use Examples**: Include usage examples when the behavior isn't obvious.
6. **Keep Updated**: Update documentation when you change the code.
7. **Use @namespace wisely**: Apply to organizational modules to achieve 100% coverage.
8. **Avoid redundancy**: For simple attributes and methods, attach descriptions directly to pragmas rather than repeating obvious information.

#### Simple Attributes and Methods

For extremely simple attributes and methods where the name clearly indicates the purpose, avoid redundant descriptions. Instead, attach the description directly to the `@attribute` pragma:

```ruby
# Good - concise and clear:
# @attribute [String] The name of the parameter.
attr :name

# @attribute [String] The type of the parameter.
attr :type

# Avoid - redundant descriptions:
# The name of the parameter.
# @attribute [String] The parameter name.
attr :name
```

This approach keeps documentation concise while still providing essential type information.

## Type Signatures

Type signatures are used to specify the expected types of parameters, return values, and attributes in Ruby code. They help clarify the intended use of methods and improve code readability.

### Primitive Types

- `String`: Represents a sequence of characters.
- `Integer`: Represents whole numbers.
- `Float`: Represents decimal numbers.
- `Boolean`: Represents true or false values.
- `Symbol`: Represents a name or identifier.

### Composite Types

- `Array(Type)`: Represents an ordered collection of items.
- `Hash(KeyType, ValueType)`: Represents a collection of key-value pairs.
- `Interface(:method1, :method2)`: Represents a contract that a class must implement, specifying required methods.
- `Type | Nil`: Represents an optional type.

## Supported Pragmas

### Type and Return Value Documentation

#### `@attribute [Type] Description.`

Documents class attributes, instance variables, and `attr_*` declarations. Prefer to have one attribute per line for clarity.

```ruby
# Represents a person with basic attributes.
class Person
	# @attribute [String] The person's full name.
	attr_reader :name
	
	# @attribute [Integer] The person's age in years.
	attr_accessor :age
	
	# @attribute [Hash] Configuration settings.
	attr_writer :config
end
```

#### `@parameter name [Type] Description.`

Documents method parameters with their types and descriptions.

```ruby
# @parameter x [Integer] The x coordinate.
# @parameter y [Integer] The y coordinate.
# @parameter options [Hash] Optional configuration.
def move(x, y, **options)
	# ...
end
```

#### `@option :key [Type] Description.`

Documents hash options (keyword arguments).

```ruby
# @parameter user [User] The user object.
# @option :cached [Boolean] Whether to cache the result.
# @option :timeout [Integer] Request timeout in seconds.
def fetch_user_data(user, **options)
	# ...
end
```

#### `@returns [Type] Description.`

Documents return values.

```ruby
# @returns [String] The formatted user name.
def full_name
	"#{first_name} #{last_name}"
end

# @returns [Array(User)] All active users.
def active_users
	users.select(&:active?)
end
```

#### `@raises [Exception] Description.`

Documents exceptions that may be raised.

```ruby
# @parameter age [Integer] The person's age.
# @raises [ArgumentError] If age is negative.
# @raises [TypeError] If age is not an integer.
def set_age(age)
	raise ArgumentError, "Age cannot be negative" if age < 0
	raise TypeError, "Age must be an integer" unless age.is_a?(Integer)
	@age = age
end
```

#### `@throws [:symbol] Description.`

Documents symbols that may be thrown (used with `catch`/`throw`).

```ruby
# @throws [:skip] To skip processing this item.
# @throws [:retry] To retry the operation.
def process_item(item)
	throw :skip if item.nil?
	throw :retry if item.invalid?
	# ...
end
```

### Block Documentation

#### `@yields {|param| ...} Description.`

Documents block parameters and behavior.

```ruby
# @yields {|item| ...} Each item in the collection.
#   @parameter item [Object] The current item being processed.
def each_item(&block)
	items.each(&block)
end

# @yields {|user, index| ...} User and their index.
#   @parameter user [User] The current user.
#   @parameter index [Integer] The user's position in the list.
def each_user_with_index(&block)
	users.each_with_index(&block)
end
```

### Visibility and Access Control

#### `@public`

Explicitly marks a method as public (useful for documentation clarity).

```ruby
# @public
def public_method
	# This method is part of the public API.
end
```

#### `@private`

Marks a method as private (for documentation purposes).

```ruby
# @private
def internal_helper
	# This method is for internal use only.
end
```

### Behavioral Documentation

#### `@deprecated Description.`

Marks methods as deprecated with migration guidance.

```ruby
# @deprecated Use {new_method} instead.
def old_method
	# Legacy implementation
end
```

#### `@asynchronous`

Indicates that a method may yield control.

```ruby
# @asynchronous
def fetch_data
	# This method may yield control during execution.
end
```

### Namespace Documentation

#### `@namespace`

Marks a module as serving only as a namespace, achieving 100% documentation coverage without requiring detailed documentation of empty container modules.

```ruby
# @namespace
module MyGem
	# This module serves only as a namespace for organizing classes.
	
	class ActualImplementation
		# This class contains the real functionality.
	end
end
```

**Why use `@namespace`?**
- Achieves 100% documentation coverage without redundant documentation.
- Clearly indicates that a module is purely organizational.
- Avoids documenting modules that exist only to group related classes.
- Maintains clean, focused documentation on actual functionality.

**When to use `@namespace`:**
- Root gem modules that only contain other classes/modules.
- Organizational modules with no methods or meaningful state.
- Modules that exist purely for constant scoping.
- Any module where documentation would add no value.

**Note:** This pragma is treated as a form of documentation by the Decode gem, satisfying coverage requirements while keeping the codebase clean.

## Special Pragmas for Code Structure

### `@name custom_name`

Overrides the default name extraction for attributes or methods.

```ruby
# @name hostname
# @attribute [String] The server hostname.
attr_reader :server_name
```

### `@scope Module::Name`

Defines scope for definitions that should be associated with a specific module.

```ruby
# @scope Database
def connect
	# This method belongs to the Database scope.
end
```
