# Project Structure - monava.nvim

## File Organization Philosophy

The project follows standard Neovim plugin conventions with a modular architecture that emphasizes clear separation of concerns, discoverability, and maintainability. Each directory and file has a specific purpose and follows established naming patterns.

## Root Directory Structure

```
monava.nvim/
├── lua/                    # Lua source code (main plugin logic)
├── plugin/                 # Neovim plugin entry point
├── tests/                  # Test suite and fixtures
├── scripts/                # Development and utility scripts
├── .claude/                # Claude Code spec workflow and configuration
├── CLAUDE.md              # Project-specific Claude instructions
├── README.md              # User documentation and setup guide
├── CONTRIBUTING.md        # Development and contribution guidelines
├── LICENSE                # MIT license file
├── Makefile               # Build and development tasks
└── stylua.toml            # Code formatting configuration
```

## Lua Module Organization

### Main Plugin Structure

```
lua/monava/
├── init.lua               # Main entry point and public API
├── config.lua             # Configuration management and validation
├── core/                  # Core business logic modules
├── adapters/              # External integration adapters
└── utils/                 # Utility functions and helpers
```

### Core Module (`lua/monava/core/`)

Contains the essential business logic for monorepo detection and management:

```
core/
└── init.lua               # Monorepo detection, package management, dependency analysis
```

**Responsibilities:**

- Monorepo type detection (JavaScript/TypeScript, Rust, Python, Go, Java)
- Package discovery and metadata extraction
- Dependency graph analysis
- Current package context detection

**Naming Convention:** Single `init.lua` file that exports comprehensive core functionality

### Adapters Module (`lua/monava/adapters/`)

Provides abstraction layer for different picker backends:

```
adapters/
└── init.lua               # Multi-picker abstraction and backend detection
```

**Responsibilities:**

- Picker backend detection and initialization
- Unified interface across Telescope, fzf-lua, and snacks.nvim
- Feature capability mapping
- Graceful fallback handling

**Pattern:** Adapter pattern with consistent interface regardless of backend

### Utils Module (`lua/monava/utils/`)

Utility functions organized by domain:

```
utils/
├── init.lua               # Utility aggregation and common functions
├── cache.lua              # Caching system and performance optimization
├── errors.lua             # Error handling, codes, and user notifications
├── fs.lua                 # Filesystem operations and path utilities
└── validation.lua         # Input validation and sanitization
```

**Naming Convention:**

- `init.lua` - Module aggregation and general utilities
- Domain-specific files (`cache.lua`, `errors.lua`, etc.)
- Snake_case filenames matching module purpose

## Plugin Integration (`plugin/`)

```
plugin/
└── monava.lua             # Neovim command registration and plugin initialization
```

**Responsibilities:**

- Register user commands (`:Monava`, `:Mp`)
- Set up autocommands if needed
- Handle plugin loading and lazy initialization

## Test Organization (`tests/`)

### Test Structure

```
tests/
├── helpers.lua            # Test utilities and common functions
├── minimal_init.lua       # Minimal Neovim setup for test environment
├── fixtures/              # Test data and mock repositories
│   └── test-workspace/    # Sample monorepo structure for testing
├── *_spec.lua            # Test files matching module structure
└── security_spec.lua     # Security-focused validation tests
```

### Test File Naming

- **Pattern**: `{module_name}_spec.lua`
- **Examples**: `config_spec.lua`, `core_spec.lua`, `adapters_spec.lua`
- **Special**: `security_spec.lua` for security-focused tests

### Test Fixtures

```
fixtures/
└── test-workspace/
    ├── package.json       # Root monorepo configuration
    ├── packages/          # Sample packages for testing
    │   ├── pkg-a/
    │   └── pkg-b/
    └── *.lua             # Test scenario files
```

## Development Scripts (`scripts/`)

```
scripts/
├── test                   # Test runner script
└── install-hooks         # Git hooks installation script
```

**Naming Convention:**

- Executable scripts without extensions
- Descriptive names indicating purpose
- Shell scripts following POSIX compatibility

## Claude Code Integration (`.claude/`)

### Spec Workflow Structure

```
.claude/
├── steering/              # Project context documents (NEW)
│   ├── product.md        # Product vision and goals
│   ├── tech.md           # Technical standards and patterns
│   └── structure.md      # This file - project organization
├── specs/                # Feature specifications
│   └── {feature-name}/
│       ├── requirements.md
│       ├── design.md
│       └── tasks.md
├── commands/             # Spec workflow commands
│   ├── spec-*.md         # Main workflow commands
│   └── {feature-name}/   # Auto-generated task commands
├── templates/            # Document templates
├── scripts/              # Command generation scripts
└── spec-config.json     # Workflow configuration
```

## Naming Conventions

### File Naming

- **Lua Files**: `snake_case.lua` (e.g., `error_handling.lua`)
- **Directories**: `snake_case` or `kebab-case` for multi-word names
- **Scripts**: No extensions, descriptive names (e.g., `test`, `install-hooks`)
- **Documentation**: `UPPERCASE.md` for root docs, `lowercase.md` for others

### Module Naming

- **Module Tables**: PascalCase or descriptive names (`M`, `config`, `errors`)
- **Functions**: `snake_case` (e.g., `get_packages`, `validate_config`)
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g., `ERROR_CODES`, `DEFAULT_CONFIG`)
- **Private Functions**: Prefix with underscore (`_internal_function`)

### Variable Naming

- **Local Variables**: `snake_case` (e.g., `package_info`, `cache_key`)
- **Configuration Keys**: `snake_case` (e.g., `picker_priority`, `max_depth`)
- **Boolean Flags**: Descriptive prefixes (`is_`, `has_`, `should_`)

## Code Organization Patterns

### Module Structure Template

```lua
-- Module header with description
local M = {}

-- Dependencies (grouped and sorted)
local dependency1 = require("module1")
local dependency2 = require("module2")

-- Constants and configuration
local CONSTANTS = {
  KEY = "value"
}

-- Private functions (prefixed with _)
local function _private_helper()
  -- Implementation
end

-- Public functions
function M.public_function()
  -- Implementation
end

-- Module exports
return M
```

### Error Handling Pattern

```lua
-- Consistent error handling across modules
local ok, result = pcall(risky_operation)
if not ok then
  errors.notify_error(errors.CODES.OPERATION_FAILED, "Context: " .. tostring(result))
  return nil
end
```

### Configuration Pattern

```lua
-- Validation and merging pattern
local function merge_config(user_config)
  local config = vim.tbl_deep_extend("force", DEFAULT_CONFIG, user_config or {})

  if not validate_config(config) then
    error("Invalid configuration provided")
  end

  return config
end
```

## Directory Creation Guidelines

### When to Create New Directories

- **Functional Grouping**: When you have 3+ related modules
- **Clear Separation**: Different responsibilities or concerns
- **Scalability**: Anticipating growth in that area

### When to Use Single Files

- **Simple Functionality**: Single-purpose modules
- **Stable Scope**: Unlikely to expand significantly
- **Clear Boundaries**: Well-defined, contained functionality

## Integration Points

### External Dependencies

- **Picker Backends**: Abstract through `adapters/` module
- **Neovim APIs**: Direct usage with version compatibility checks
- **System Tools**: Optional dependencies with graceful fallback

### Internal Dependencies

- **Core → Utils**: Core modules may use utilities
- **Adapters → Core**: Adapters consume core functionality
- **Init → All**: Main entry point coordinates all modules
- **Config → Utils**: Configuration uses validation utilities

## File Placement Rules

### New Feature Implementation

1. **Core Logic**: Add to `core/` if it's fundamental monorepo functionality
2. **Integration**: Add to `adapters/` if it's picker-backend specific
3. **Utilities**: Add to `utils/` if it's reusable across modules
4. **Configuration**: Extend `config.lua` for new settings

### Test File Placement

1. **Unit Tests**: `tests/{module_name}_spec.lua`
2. **Integration Tests**: Include in relevant module test file
3. **Fixtures**: `tests/fixtures/` for sample data
4. **Helpers**: Add to `tests/helpers.lua` for test utilities

### Documentation Placement

1. **User Docs**: Root level (README.md, CONTRIBUTING.md)
2. **API Docs**: Inline with code
3. **Specs**: `.claude/specs/{feature-name}/`
4. **Templates**: `.claude/templates/`

## Consistency Guidelines

### Import Organization

```lua
-- Standard library (if any)
local os = os
local table = table

-- Third-party dependencies
local telescope = require("telescope")

-- Project modules (grouped by type)
local config = require("monava.config")
local core = require("monava.core")
local utils = require("monava.utils")
```

### Function Organization Within Files

1. **Constants and configuration** (top)
2. **Private helper functions** (prefixed with `_`)
3. **Public functions** (main functionality)
4. **Module exports** (bottom)

### Comment Standards

```lua
-- Module-level description
-- Brief description of the module's purpose and key functionality

-- Function documentation (for public functions)
-- @param param_name type: Description
-- @return type: Description
function M.public_function(param_name)
  -- Implementation with inline comments for complex logic
end
```

This structure ensures consistency, maintainability, and clear separation of concerns while following established Neovim plugin conventions.
