# Technical Standards - monava.nvim

## Technology Stack

### Core Technologies

- **Language**: Lua (5.1/5.2/5.3/LuaJIT compatible)
- **Platform**: Neovim >= 0.9.0
- **Architecture**: Modular plugin with adapter pattern

### Runtime Dependencies

- **Required**: Neovim with one of the supported picker backends
- **Picker Backends**: Telescope.nvim, fzf-lua, or snacks.nvim
- **Optional**: Git (for enhanced monorepo detection)

### Development Dependencies

- **Formatting**: StyLua for Lua code formatting
- **Linting**: luacheck for Lua static analysis
- **Shell Linting**: shellcheck for shell script validation
- **Markdown**: prettier for documentation formatting
- **Build System**: GNU Make for task automation

## Code Quality Standards

### Formatting Configuration (StyLua)

```toml
column_width = 100
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

### Linting Standards

- **Lua**: All code must pass luacheck with zero warnings
- **Shell Scripts**: All scripts must pass shellcheck validation
- **Documentation**: Markdown files must be formatted with prettier

### Error Handling Requirements

- **No Silent Failures**: All errors must be explicitly handled
- **User Feedback**: Provide clear error messages to users
- **Error Codes**: Use structured error codes for consistency
- **Graceful Degradation**: Plugin should work with reduced functionality if optional features fail

## Architecture Patterns

### Module Structure

```
lua/monava/
├── init.lua           # Main entry point with public API
├── config.lua         # Configuration management and validation
├── core/             # Core business logic
│   └── init.lua      # Monorepo detection and management
├── adapters/         # Picker backend adapters
│   └── init.lua      # Multi-picker abstraction layer
└── utils/            # Utility modules
    ├── cache.lua     # Caching system
    ├── errors.lua    # Error handling and codes
    ├── fs.lua        # Filesystem utilities
    ├── validation.lua # Input validation
    └── init.lua      # Utility aggregation
```

### Design Patterns

- **Adapter Pattern**: Abstraction layer for different picker backends
- **Module Pattern**: Each file exports a single module table
- **Factory Pattern**: Configuration system creates validated config objects
- **Observer Pattern**: Event-driven cache invalidation

### Error Handling Architecture

```lua
-- Structured error codes
local CODES = {
  INVALID_INPUT = "INVALID_INPUT",
  CACHE_ERROR = "CACHE_ERROR",
  PICKER_ERROR = "PICKER_ERROR",
}

-- Consistent error notification
errors.notify_error(CODES.INVALID_INPUT, "Detailed error message")
```

## Performance Requirements

### Caching Strategy

- **Module-level Caching**: 5-second TTL for package information
- **Race Condition Protection**: Lock mechanism prevents concurrent cache refreshes
- **Cache Invalidation**: Automatic invalidation on configuration changes
- **Graceful Fallback**: Return stale cache on refresh failures

### Performance Targets

- **Initialization**: < 50ms plugin setup time
- **Package Discovery**: < 100ms for monorepo detection
- **Navigation**: < 50ms for package switching
- **File Search**: Leverage picker backend performance

### Memory Management

- **Lazy Loading**: Modules loaded on first use
- **Cache Limits**: Reasonable memory usage for large monorepos
- **Cleanup**: Proper cleanup of temporary resources

## Security Considerations

### Input Validation

- **Package Names**: Validate against filesystem-safe patterns
- **File Paths**: Prevent directory traversal attacks
- **Configuration**: Validate all user-provided configuration options

### Safe Operations

- **Filesystem Access**: Only read operations, no destructive actions
- **Command Execution**: No arbitrary command execution
- **Error Information**: Don't leak sensitive paths in error messages

## Testing Standards

### Test Structure

```
tests/
├── helpers.lua           # Test utilities and fixtures
├── minimal_init.lua     # Minimal Neovim setup for tests
├── fixtures/            # Test data and mock monorepos
│   └── test-workspace/  # Sample monorepo for testing
├── *_spec.lua          # Test files matching module structure
└── security_spec.lua   # Security-focused tests
```

### Test Requirements

- **Unit Tests**: Each module must have corresponding tests
- **Integration Tests**: Test picker backend integration
- **Security Tests**: Validate input sanitization and safe operations
- **Performance Tests**: Verify caching and performance targets
- **Error Scenarios**: Test all error handling paths

### Test Patterns

```lua
-- Test module structure
describe("module_name", function()
  setup(function()
    -- Test setup
  end)

  it("should handle normal case", function()
    -- Test implementation
  end)

  it("should handle error case", function()
    -- Error handling tests
  end)
end)
```

## Build and Development Tools

### Make Targets

- `make test` - Run all tests
- `make lint` - Run linting checks
- `make format` - Format all code
- `make format-check` - Check formatting without changes
- `make check` - Run all quality checks (lint + format + test)
- `make clean` - Clean temporary files
- `make install-hooks` - Install git pre-commit hooks

### Git Hooks

- **Pre-commit**: Run linting and formatting checks
- **Quality Gates**: Prevent commits that don't meet standards

### Development Workflow

1. **Setup**: Run `make install-hooks` after cloning
2. **Development**: Follow TDD practices with `make test`
3. **Quality**: Run `make check` before committing
4. **Integration**: Use git hooks for automated quality checks

## Configuration System

### Configuration Validation

```lua
-- Required validation for all config options
local function validate_config(config)
  -- Type checking
  -- Range validation
  -- Pattern matching
  -- Dependency validation
end
```

### Default Configuration

```lua
{
  debug = false,
  picker_priority = { 'telescope', 'fzf-lua', 'snacks' },
  cache = {
    enabled = true,
    ttl = 300, -- 5 minutes
  },
  detection = {
    max_depth = 3,
    patterns = {
      javascript = { 'package.json', 'nx.json', 'lerna.json' },
      rust = { 'Cargo.toml' },
    },
  },
  keymaps = {
    packages = '<leader>mp',
    switch = '<leader>ms',
    files = '<leader>mf',
    dependencies = '<leader>md',
    info = '<leader>mi',
  },
}
```

## Integration Standards

### Picker Backend Requirements

- **Consistent Interface**: All pickers must implement the same methods
- **Error Handling**: Graceful fallback if picker unavailable
- **Feature Parity**: Core features work across all picker backends
- **Performance**: No significant performance degradation

### Neovim Integration

- **Health Check**: Implement `:checkhealth monava` support
- **Commands**: Standard command patterns with completion
- **Keymaps**: Configurable with standard leader key patterns
- **Help Tags**: Complete documentation with help tags

## Documentation Standards

### Code Documentation

- **Module Headers**: Clear description of module purpose
- **Function Documentation**: Parameters, return values, and examples
- **Complex Logic**: Inline comments for non-obvious implementations
- **TODOs**: Track technical debt with standard TODO comments

### User Documentation

- **README**: Comprehensive setup and usage instructions
- **Help Files**: Neovim help documentation
- **Examples**: Real-world usage examples
- **Troubleshooting**: Common issues and solutions

## Compatibility Requirements

### Neovim Versions

- **Minimum**: Neovim 0.9.0
- **Recommended**: Latest stable Neovim
- **API Usage**: Use stable Neovim APIs only

### Operating System Support

- **Primary**: Linux and macOS
- **Secondary**: Windows (best effort)
- **Testing**: CI testing on major platforms

### Lua Version Compatibility

- **LuaJIT**: Primary target (Neovim default)
- **Lua 5.1/5.2/5.3**: Compatible code patterns
- **Libraries**: Use only Neovim-bundled libraries
