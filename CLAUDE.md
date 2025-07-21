# monava.nvim - AI assistant instructions

monava.nvim-specific instructions for AI assistants working on this project.

## 🎯 Project context

monava.nvim is a modern Neovim plugin for intelligent monorepo navigation and management. It provides a unified interface for different picker backends (Telescope, fzf-lua, snacks.nvim) to browse packages, switch workspaces, and find files within monorepo structures.

### Key documentation

- **[README.md](README.md)**: Project overview, installation, and configuration
- **[Makefile](Makefile)**: Build targets and quality checks
- **[tests/](tests/)**: Test suite with Busted framework

## 🚨 Critical requirements

### Development workflow

- **Always run `./scripts/test`**: Run tests (executable script) after code changes
- **Use `make check`**: Run all quality checks (lint + format-check + test)
- **Use `make format`**: Format Lua and shell scripts before commits

### Key implementation notes

- **Multi-picker architecture**: Abstraction layer in `lua/monava/adapters/` supporting different finder backends
- **Modular design**: Separated into core, adapters, config, and utils modules
- **Caching system**: Module-level package caching with 5-second TTL for performance
- **Comprehensive error handling**: Validation and user notifications throughout
- **Busted-style tests**: Use `describe`/`it`/`assert` with lazy.nvim minimal runner
- **Performance focus**: Efficient algorithms for large monorepos with caching

## 🏗️ Architecture overview

### Core modules

- **`lua/monava/init.lua`**: Main entry point with setup and public API
- **`lua/monava/core/`**: Monorepo detection and package management
- **`lua/monava/adapters/`**: Picker backend abstraction layer
- **`lua/monava/config.lua`**: Configuration validation and keymap setup
- **`lua/monava/utils/`**: Filesystem, caching, and utility functions

### Testing infrastructure

- **`tests/minimal_init.lua`**: Lazy.nvim test environment setup
- **`scripts/test`**: Test runner script with verbose options
- **Busted framework**: BDD-style testing with `describe`/`it` blocks

### Development tools

- **Makefile**: Comprehensive targets for testing, linting, formatting
- **stylua.toml**: Lua code formatting configuration
- **luacheck**: Lua static analysis (via `make lint`)
- **shfmt**: Shell script formatting

## 🔧 Development patterns

### Error handling

- Use `pcall()` for component initialization
- Provide clear error messages with `vim.notify()`
- Validate inputs and return early on invalid data
- Never fail silently - always inform the user

### Caching strategy

- Module-level caching with timestamps for package data
- 5-second TTL for package cache to balance performance and freshness
- Invalidation methods for cache management
- Don't cache empty results

### Code organization

- Follow existing module structure in `lua/monava/`
- Separate concerns: core logic, adapters, configuration, utilities
- Use consistent naming conventions and require patterns
- Keep functions focused and testable

### Testing approach

- Write tests for all public functions
- Use helper functions in `tests/helpers.lua`
- Test error conditions and edge cases
- Mock external dependencies when needed

## 🎛️ Configuration system

The plugin uses a layered configuration approach:

- Default values in `lua/monava/config.lua`
- User overrides via `setup()` function
- Runtime validation and merging
- Debug mode for development assistance

Key configuration areas:

- Picker priority ordering
- Cache settings (TTL, enabled state)
- Detection patterns for monorepo types
- Keymap definitions
- Debug mode toggle

## 🚀 Performance considerations

- **Lazy initialization**: Components load only when needed
- **Efficient caching**: Smart cache invalidation and TTL management
- **Minimal file system operations**: Cache results of expensive operations
- **Async patterns**: Use Neovim's async capabilities where appropriate
- **Memory management**: Clean up resources and avoid memory leaks

## 🧪 Testing guidelines

- Run `./scripts/test` for full test suite
- Add tests for new functionality in corresponding `*_spec.lua` files
- Use `tests/helpers.lua` for common test utilities
- Test both success and failure scenarios
- Ensure tests are independent and can run in any order

## 🔍 Debugging support

- Enable debug mode via `setup({ debug = true })`
- Use `vim.notify()` for user-facing messages
- Leverage `:checkhealth monava` for system validation
- Check `M.get_config()` for runtime configuration state
