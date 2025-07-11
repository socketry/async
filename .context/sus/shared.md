# Shared Test Behaviors and Fixtures

## Overview

Sus provides shared test contexts which can be used to define common behaviours or tests that can be reused across one or more test files.

When you have common test behaviors that you want to apply to multiple test files, add them to the `fixtures/` directory. When you have common test behaviors that you want to apply to multiple implementations of the same interface, within a single test file, you can define them as shared contexts within that file.

## Shared Fixtures

### Directory Structure

```
my-gem/
├── lib/
│   ├── my_gem.rb
│   └── my_gem/
│       └── my_thing.rb
├── fixtures/
│   └── my_gem/
│       └── a_thing.rb               # Provides MyGem::AThing shared context
└── test/
    ├── my_gem.rb
    └── my_gem/
        └── my_thing.rb
```

### Creating Shared Fixtures

Create shared behaviors in the `fixtures/` directory using `Sus::Shared`:

```ruby
# fixtures/my_gem/a_user.rb

require "sus/shared"

module MyGem
	AUser = Sus::Shared("a user") do |role|
		let(:user) do
			{
				name: "Test User",
				email: "test@example.com",
				role: role
			}
		end
		
		it "has a name" do
			expect(user[:name]).not.to be_nil
		end
		
		it "has a valid email" do
			expect(user[:email]).to be(:include?, "@")
		end
		
		it "has a role" do
			expect(user[:role]).to be_a(String)
		end
	end
end
```

### Using Shared Fixtures

Require and use shared fixtures in your test files:

```ruby
# test/my_gem/user_manager.rb
require 'my_gem/a_user'

describe MyGem::UserManager do
	it_behaves_like MyGem::AUser, "manager"
	# or include_context MyGem::AUser, "manager"
end
```

### Multiple Shared Fixtures

You can create multiple shared fixtures for different scenarios:

```ruby
# fixtures/my_gem/users.rb
module MyGem
	module Users
		AStandardUser = Sus::Shared("a standard user") do
			let(:user) do
				{ name: "John Doe", role: "user", active: true }
			end
			
			it "is active" do
				expect(user[:active]).to be_truthy
			end
		end
		
		AnAdminUser = Sus::Shared("an admin user") do
			let(:user) do
				{ name: "Admin User", role: "admin", active: true }
			end
			
			it "has admin role" do
				expect(user[:role]).to be == "admin"
			end
		end
	end
end
```

Use specific shared fixtures:

```ruby
# test/my_gem/authorization.rb
require 'my_gem/users'

describe MyGem::Authorization do
	with "standard user" do
		# If there are no arguments, you can use `include` directly:
		include MyGem::Users::AStandardUser
		
		it "denies admin access" do
			auth = subject.new
			expect(auth.can_admin?(user)).to be_falsey
		end
	end
	
	with "admin user" do
		include MyGem::Users::AnAdminUser
		
		it "allows admin access" do
			auth = subject.new
			expect(auth.can_admin?(user)).to be_truthy
		end
	end
end
```

### Modules

You can also define shared behaviors in modules and include them in your test files:

```ruby
# fixtures/my_gem/shared_behaviors.rb
module MyGem
	module SharedBehaviors
		def self.included(base)
			base.it "uses shared data" do
				expect(shared_data).to be == "some shared data"
			end
		end
		
		def shared_data
			"some shared data"
		end
	end
end
```

### Enumerating Tests

Some tests will be run multiple times with different arguments (for example, multiple database adapters). You can use `Sus::Shared` to define these tests and then enumerate them:

```ruby
# test/my_gem/database_adapter.rb

require "sus/shared"

ADatabaseAdapter = Sus::Shared("a database adapter") do |adapter|
	let(:database) {adapter.new}
	
	it "connects to the database" do
		expect(database.connect).to be_truthy
	end
	
	it "can execute queries" do
		expect(database.execute("SELECT 1")).to be == [[1]]
	end
end

# Enumerate the tests with different adapters
MyGem::DatabaseAdapters.each do |adapter|
	describe "with #{adapter}", unique: adapter.name do
		it_behaves_like ADatabaseAdapter, adapter
	end
end
```

Note the use of `unique: adapter.name` to ensure each test is uniquely identified, which is useful for reporting and debugging - otherwise the same test line number would be used for all iterations, which can make it hard to identify which specific test failed.
