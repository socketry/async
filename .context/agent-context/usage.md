# Usage Guide

## What is agent-context?

`agent-context` is a tool that helps you discover and install contextual information from Ruby gems for AI agents. Gems can provide additional documentation, examples, and guidance in a `context/` directory.

## Quick Commands

```bash
# See what context is available
bake agent:context:list

# Install all available context
bake agent:context:install

# Install context from a specific gem
bake agent:context:install --gem async

# See what context files a gem provides
bake agent:context:list --gem async

# View a specific context file
bake agent:context:show --gem async --file thread-safety
```

## Understanding context/ vs .context/

**Important distinction:**
- **`context/`** (no dot) = Directory in gems that contains context files to share.
- **`.context/`** (with dot) = Directory in your project where context gets installed.

### What happens when you install context?

When you run `bake agent:context:install`, the tool:

1. Scans all installed gems for `context/` directories (in the gem's root).
2. Creates a `.context/` directory in your current project.
3. Copies context files organized by gem name.

For example:
```
your-project/
├── .context/           # ← Installed context (with dot)
│   ├── async/          # ← From the 'async' gem's context/ directory
│   │   ├── thread-safety.md
│   │   └── performance.md
│   └── rack/           # ← From the 'rack' gem's context/ directory
│       └── middleware.md
├── lib/
└── Gemfile
```

Meanwhile, in the gems themselves:
```
async-gem/
├── context/            # ← Source context (no dot)
│   ├── thread-safety.md
│   └── performance.md
├── lib/
└── async.gemspec
```

## Using Context (For Gem Users)

### Why use this?

- **Discover hidden documentation** that gems provide.
- **Get practical examples** and guidance.
- **Understand best practices** from gem authors.
- **Access migration guides** and troubleshooting tips.

### Key Points for Users

- Run `bake agent:context:install` to copy context to `.context/` (with dot).
- The `.context/` directory is where installed context lives in your project.
- Don't edit files in `.context/` - they get completely replaced when you reinstall.

## Providing Context (For Gem Authors)

### How to provide context in your gem

#### 1. Create a `context/` directory

In your gem's root directory, create a `context/` folder (no dot):

```
your-gem/
├── context/            # ← Source context (no dot) - this is what you create
│   ├── getting-started.md
│   ├── configuration.md
│   └── troubleshooting.md
├── lib/
└── your-gem.gemspec
```

**Important:** This is different from `.context/` (with dot) which is where context gets installed in user projects.

#### 2. Add context files

Create files with helpful information for users of your gem. Common types include:

- **getting-started.md** - Quick start guide for using your gem.
- **configuration.md** - Configuration options and examples.
- **troubleshooting.md** - Common issues and solutions.
- **migration.md** - Migration guides between versions.
- **performance.md** - Performance tips and best practices.
- **security.md** - Security considerations.

**Focus on the agent experience:** These files should help AI agents understand how to use your gem effectively, not document your gem's internal APIs.

#### 3. Document your context

Add a section to your gem's README:

```markdown
## Context

This gem provides additional context files that can be installed using `bake agent:context:install`.

Available context files:
- `getting-started.md` - Quick start guide.
- `configuration.md` - Configuration options.
- `troubleshooting.md` - Common issues and solutions.
```

#### 4. File format and content guidelines

Context files can be in any format, but `.md` is commonly used for documentation. The content should be:

- **Practical** - Include real examples and working code.
- **Focused** - One topic per file.
- **Clear** - Easy to understand and follow.
- **Actionable** - Provide specific guidance and next steps.
- **Agent-focused** - Help AI agents understand how to use your gem effectively.

### Key Points for Gem Authors

- Create a `context/` directory (no dot) in your gem's root.
- Put helpful guides for users of your gem there.
- Focus on practical usage, not API documentation.

## Example Context Files

For examples of well-structured context files, see the existing files in this directory:
- `usage.md` - Shows how to use the tool (this file).
- `examples.md` - Demonstrates practical usage scenarios.

## Key Differences from API Documentation

Context files are NOT the same as API documentation:

- **Context files**: Help agents accomplish tasks ("How do I configure authentication?").
- **API documentation**: Document methods and classes ("Method `authenticate` returns Boolean").

Context files should answer questions like:
- "How do I get started?".
- "How do I configure this for production?".
- "What do I do when X goes wrong?".
- "How do I migrate from version Y to Z?".

## Testing Your Context

Before publishing, test your context files:

1. Have an AI agent try to follow your getting-started guide.
2. Check that all code examples actually work.
3. Ensure the files are focused and don't try to cover too much.
4. Verify that they complement rather than duplicate your main documentation.

## Summary

- **`context/`** = source (in gems).
- **`.context/`** = destination (in your project).
