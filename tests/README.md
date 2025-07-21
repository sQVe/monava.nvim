# Test Suite Documentation

This directory contains comprehensive tests for monava.nvim using the Busted testing framework, following the same structure as [sort.nvim](https://github.com/sQVe/sort.nvim).

## Structure

```
tests/
├── README.md              # This documentation
├── minimal_init.lua       # Test environment with Lazy.nvim setup
├── helpers.lua            # Test utility functions
├── config_spec.lua        # Configuration system tests
├── core_spec.lua          # Core detection logic tests
├── utils_spec.lua         # Utility function tests (fs, cache)
├── adapters_spec.lua      # Picker adapter tests
└── init_spec.lua          # Main plugin integration tests
```

## Quick Start

### Prerequisites

1. **Neovim** 0.8+ is required
2. **Busted** testing framework: `luarocks install busted`
3. **Lazy.nvim** (automatically downloaded during test initialization)

### Running Tests

```bash
# Run all tests
./scripts/test

# Run tests with verbose output
./scripts/test --verbose

# Or use Make targets
make test
make test-verbose
```

## Testing Framework

### Busted + Lazy.nvim Setup

The test suite uses **Busted** as the testing framework with **Lazy.nvim** for plugin management during tests:

- **`.busted`**: Busted configuration with verbose output enabled
- **`minimal_init.lua`**: Sets up isolated test environment with Lazy.nvim
- **`scripts/test`**: Test runner script (executable)

### Test File Structure

All test files follow the `*_spec.lua` naming convention and use BDD-style structure:

```lua
local helpers = require('tests.helpers')

describe('module_name', function()
  before_each(function()
    -- Setup code
  end)

  after_each(function()
    helpers.fs_rm() -- Cleanup test files
  end)

  describe('feature_name', function()
    it('should behave correctly', function()
      -- Test assertions
      assert.are.equal('expected', actual)
    end)

    it('should handle edge cases', function()
      helpers.assert_error(function()
        -- Code that should error
      end, 'Expected error message')
    end)
  end)
end)
```

## Test Utilities (helpers.lua)

The helpers module provides utilities for file system operations and mocking:

### File System Helpers

```lua
local helpers = require('tests.helpers')

-- Create test file structure
local workspace = helpers.fs_create({
  ['package.json'] = '{"name": "test"}',
  ['src/index.js'] = 'console.log("hello");'
})

-- Get path relative to test fs root
local file_path = helpers.path('package.json')

-- Cleanup test files
helpers.fs_rm()
```

### Mocking Utilities

```lua
-- Mock vim.notify
local mock = helpers.mock_notify()
-- ... test code ...
assert.is.true(#mock.notifications > 0)
mock.restore()

-- Mock vim.ui.select
local ui_mock = helpers.mock_ui_select()
-- ... test code ...
assert.is.true(#ui_mock.selections > 0)
ui_mock.restore()

-- Assert table has keys
helpers.assert_has_keys(table, {'key1', 'key2'})

-- Assert function throws error
helpers.assert_error(function()
  error('test error')
end, 'test error')
```

## Test Categories

### Unit Tests

- **`config_spec.lua`**: Configuration merging, validation, keymap setup
- **`utils_spec.lua`**: File system utilities and caching system tests
- **`core_spec.lua`**: Monorepo detection and package enumeration logic

### Integration Tests

- **`adapters_spec.lua`**: Picker integration (Telescope, fzf-lua, mini.pick)
- **`init_spec.lua`**: Main plugin functionality, commands, error handling

## Code Quality and CI/CD

### Pre-commit Hooks

```bash
# Install git hooks
./scripts/install-hooks

# Or use Make
make install-hooks
```

The pre-commit hooks will:

- Format Lua files with `stylua`
- Format shell scripts with `shfmt`
- Run linting with `luacheck`
- Prevent commits if checks fail

### Manual Quality Checks

```bash
# Run all quality checks
make check

# Individual checks
make lint          # Run luacheck
make format        # Format all code
make format-check  # Check formatting without changes
make test          # Run test suite
```

### GitHub Actions

The CI/CD pipeline runs on:

- **Push/PR**: Test suite, linting, and formatting checks
- **Release tags**: Full test suite + automated release creation

## Development Workflow

### Adding New Tests

1. Create test file with `*_spec.lua` naming
2. Use `helpers.fs_create()` for test file structures
3. Follow BDD structure with `describe()` and `it()` blocks
4. Clean up with `helpers.fs_rm()` in `after_each()`
5. Mock external dependencies appropriately

### Test Coverage Goals

- **Unit Tests**: 90%+ coverage for core logic
- **Integration Tests**: All user-facing functionality
- **Edge Cases**: Error conditions and boundary values
- **Performance**: Large workspace handling

### Best Practices

1. **Isolation**: Each test is independent
2. **Cleanup**: Always clean up test files and mocks
3. **Clear Names**: Descriptive test descriptions
4. **Mock External**: Mock vim APIs and external dependencies
5. **Test Behavior**: Focus on what the code does, not how

## Debugging

### Running Specific Tests

```bash
# Run with verbose output for debugging
./scripts/test --verbose

# Run individual test file manually
nvim -l tests/minimal_init.lua --minitest tests/config_spec.lua
```

### Common Issues

1. **Test Isolation**: Ensure `package.loaded[module] = nil` before requiring
2. **File Cleanup**: Always use `helpers.fs_rm()` to clean up test files
3. **Mock Restoration**: Restore original functions after mocking
4. **Path Issues**: Use `helpers.path()` for test file paths

## Dependencies

### Required Tools

```bash
# Core testing
luarocks install busted

# Code formatting
cargo install stylua
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Linting
luarocks install luacheck
```

### Optional Enhancements

```bash
# Test coverage (if implemented)
luarocks install luacov

# File watching for continuous testing
brew install entr  # macOS
apt install entr   # Ubuntu
```

## Contributing

When adding new features:

1. **Write Tests First**: Follow TDD when possible
2. **Test All Paths**: Include success and failure scenarios
3. **Follow Patterns**: Use existing test patterns and helpers
4. **Update Documentation**: Keep this README current
5. **Run Quality Checks**: `make check` before committing

The test suite ensures monava.nvim remains reliable and maintainable across different Neovim versions and environments.
