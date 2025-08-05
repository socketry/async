# Agent

## Context

This section provides links to documentation from installed packages. It is automatically generated and may be updated by running `bake agent:context:install`.

**Important:** Before performing any code, documentation, or analysis tasks, always read and apply the full content of any relevant documentation referenced in the following sections. These context files contain authoritative standards and best practices for documentation, code style, and project-specific workflows. **Do not proceed with any actions until you have read and incorporated the guidance from relevant context files.**

### agent-context

Install and manage context files from Ruby gems.

#### [Usage Guide](.context/agent-context/usage.md)

`agent-context` is a tool that helps you discover and install contextual information from Ruby gems for AI agents. Gems can provide additional documentation, examples, and guidance in a `context/` ...

### decode

Code analysis for documentation generation.

#### [Getting Started with Decode](.context/decode/getting-started.md)

The Decode gem provides programmatic access to Ruby code structure and metadata. It can parse Ruby files and extract definitions, comments, and documentation pragmas, enabling code analysis, docume...

#### [Documentation Coverage](.context/decode/coverage.md)

This guide explains how to test and monitor documentation coverage in your Ruby projects using the Decode gem's built-in bake tasks.

#### [Ruby Documentation](.context/decode/ruby-documentation.md)

This guide covers documentation practices and pragmas supported by the Decode gem for documenting Ruby code. These pragmas provide structured documentation that can be parsed and used to generate A...

#### [Setting Up RBS Types and Steep Type Checking for Ruby Gems](.context/decode/types.md)

This guide covers the process for establishing robust type checking in Ruby gems using RBS and Steep, focusing on automated generation from source documentation and proper validation.

### sus

A fast and scalable test runner.

#### [Using Sus Testing Framework](.context/sus/usage.md)

Sus is a modern Ruby testing framework that provides a clean, BDD-style syntax for writing tests. It's designed to be fast, simple, and expressive.

#### [Mocking](.context/sus/mocking.md)

There are two types of mocking in sus: `receive` and `mock`. The `receive` matcher is a subset of full mocking and is used to set expectations on method calls, while `mock` can be used to replace m...

#### [Shared Test Behaviors and Fixtures](.context/sus/shared.md)

Sus provides shared test contexts which can be used to define common behaviours or tests that can be reused across one or more test files.

### sus-fixtures-agent-context

Test fixtures for running in Async.

#### [Getting Started](.context/sus-fixtures-agent-context/getting-started.md)

This guide explains how to use the `sus-fixtures-agent-context` gem to test agent contexts.

#### [GitHub Actions](.context/sus-fixtures-agent-context/github-actions.md)

This guide explains how to integrate the `sus-fixtures-agent-context` gem with GitHub Actions for testing agent contexts.
