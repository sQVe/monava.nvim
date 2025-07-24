# Foundation Fixes - Design

## Overview
Comprehensive technical design for implementing critical foundation improvements including MEMORY.md priorities (input validation, error handling) PLUS architectural decomposition and reliability enhancements identified in code review. This design addresses both immediate needs and long-term architectural health.

## Architecture

### Phase 1: Immediate Fixes (MEMORY.md)
```
lua/monava/utils/
├── validation.lua    # Input validation functions (NEW)
└── errors.lua       # Standardized error handling (NEW)
```

### Phase 2: Core Architecture Decomposition
```
lua/monava/core/
├── init.lua              # Public API only (~50 lines)
├── detector.lua          # Monorepo type detection (NEW)
├── cache_manager.lua     # Centralized cache operations (NEW)
├── resource_manager.lua  # Resource cleanup & lifecycle (NEW)
└── parsers/              # Format-specific parsers (NEW)
    ├── npm.lua           # NPM workspace parsing
    ├── pnpm.lua          # PNPM workspace parsing  
    ├── nx.lua            # Nx monorepo parsing
    ├── cargo.lua         # Cargo workspace parsing
    └── base.lua          # Common parsing utilities
```

### Phase 3: Enhanced Architecture
```  
lua/monava/
├── core/                 # Core business logic
│   ├── init.lua         # Public API coordination
│   ├── detector.lua     # Monorepo detection strategies
│   ├── cache_manager.lua # Cache with LRU eviction
│   ├── resource_manager.lua # Resource lifecycle
│   └── parsers/         # Modular format parsers
├── utils/               # Enhanced utilities
│   ├── validation.lua   # Input validation
│   ├── errors.lua       # Standardized errors
│   ├── async.lua        # Async with concurrency limits (NEW)
│   ├── fs.lua           # Enhanced file operations
│   └── cache.lua        # Thread-safe caching
└── adapters/            # UI adapters (unchanged)
    └── init.lua         # Multi-picker support
```

## Component Specifications

## Phase 1 Components (MEMORY.md Priorities)

### 1. Validation Module (`lua/monava/utils/validation.lua`)

#### Purpose
Centralized input validation to prevent invalid parameters from causing crashes or unexpected behavior.

#### Interface
```lua
local validation = require('monava.utils.validation')

-- Core validation functions
validation.validate_package_name(name) -> boolean, string|nil
validation.validate_config(config) -> boolean, string|nil
validation.validate_picker_opts(opts) -> boolean, string|nil
```

#### Implementation Details
- **Package Name Validation**: Regex pattern `^[%w@][%w@%-%./]*$`
- **Length Limits**: Package names max 255 characters
- **Type Checking**: Ensure string types where expected
- **Nil Handling**: Explicit nil checks with descriptive messages

### 2. Error Handling Module (`lua/monava/utils/errors.lua`)

#### Purpose
Consistent error formatting and notification across all plugin functions.

#### Interface
```lua
local errors = require('monava.utils.errors')

-- Error notification with codes
errors.notify_error(code, message, details?) -> void
errors.CODES -> table<string, string>
```

#### Error Code System
```lua
ERROR_CODES = {
  INVALID_INPUT = "E001",    -- Parameter validation failures
  NO_MONOREPO = "E002",      -- Monorepo detection failures  
  PICKER_FAILED = "E003",    -- Picker operation failures
  CACHE_ERROR = "E004",      -- Cache operation failures
}
```

#### Message Format
```
[monava:E001] Package name cannot be nil
Details: Function M.files() requires a valid package name parameter
```

## Integration Points

### 1. Main API Functions (`lua/monava/init.lua`)

**Target Functions:**
- `M.files()` (line 166)
- `M.dependencies()` (line 194)
- `M.packages()` (existing)

**Integration Pattern:**
```lua
function M.files(package_name, opts)
  local valid, err = validation.validate_package_name(package_name)
  if not valid then
    errors.notify_error(errors.CODES.INVALID_INPUT, err)
    return
  end
  -- ... existing logic
end
```

### 2. Core Functions (`lua/monava/core/init.lua`)

**Target Areas:**
- Package discovery functions (lines 557-898)
- Configuration processing
- Monorepo detection

**Integration Pattern:**
```lua
local success, result = pcall(function()
  -- existing logic
end)

if not success then
  errors.notify_error(errors.CODES.NO_MONOREPO, "Failed to detect monorepo", result)
  return nil
end
```

## Code Reuse Analysis

### Existing Patterns to Leverage
1. **Error Handling**: Current `vim.notify(msg, vim.log.levels.ERROR)` pattern
2. **Validation Style**: Existing type checks in configuration module
3. **Module Structure**: Follow existing `utils/` module organization
4. **Return Patterns**: Consistent with existing boolean, error_message returns

### Existing Code to Extend
- **Config Validation**: `lua/monava/config.lua` has validation patterns to follow
- **Error Messages**: Current error handling in adapters and core modules
- **Utility Organization**: `lua/monava/utils/init.lua` structure and patterns

## Error Handling Strategy

### 1. Validation Errors (E001)
- **Trigger**: Invalid function parameters
- **Response**: Early return with user notification
- **Recovery**: User corrects input and retries

### 2. System Errors (E002-E004)  
- **Trigger**: Runtime failures (monorepo detection, picker, cache)
- **Response**: Graceful degradation with informative messages
- **Recovery**: Automatic fallbacks where possible

### 3. Error Propagation
- **Public APIs**: Convert to user-friendly notifications
- **Internal Functions**: Preserve technical details for debugging
- **Test Environment**: Allow error bubbling for test assertions

## Testing Strategy

### Unit Tests
- **Validation Functions**: Test all edge cases and valid inputs
- **Error Formatting**: Verify message format consistency
- **Integration**: Test error handling in main API functions

### Test Files
```
tests/utils/
├── validation_spec.lua   # Validation function tests
├── errors_spec.lua       # Error handling tests
└── integration_spec.lua  # API integration tests
```

### Test Scenarios
- Valid inputs (should pass through unchanged)
- Invalid inputs (should trigger proper error codes)
- Edge cases (empty strings, special characters, length limits)
- Error message formatting and consistency

## Performance Considerations

### Validation Overhead
- **Impact**: Minimal - simple regex and type checks
- **Optimization**: Early returns for common valid cases
- **Measurement**: No measurable impact on function call time

### Error Handling Overhead
- **Impact**: Zero in happy path (no errors)
- **Error Path**: Acceptable overhead for error formatting
- **Memory**: Minimal string concatenation for error messages

## Backward Compatibility

### API Compatibility
- **Public Functions**: No signature changes
- **Return Values**: Same return patterns
- **Error Behavior**: Enhanced but not breaking

### Migration Strategy
- **Phase 1**: Add validation to new utility modules
- **Phase 2**: Integrate into existing functions with fallbacks
- **Phase 3**: Comprehensive error code adoption

## Implementation Priority

### Phase 1: Core Modules (2 hours)
1. Create `validation.lua` with package name validation
2. Create `errors.lua` with error code system  
3. Add basic unit tests

### Phase 2: Integration (1 hour)
1. Integrate validation into `M.files()` and `M.dependencies()`
2. Replace ad-hoc error messages with standardized format
3. Verify backward compatibility

## Phase 2 Components (Core Architecture Decomposition)

### 3. Core Module Decomposition (`lua/monava/core/`)

#### New Core Init (`lua/monava/core/init.lua`)
**Purpose**: Coordinate between specialized modules, maintain public API
**Size Target**: <100 lines (down from 898)
**Responsibilities**:
- Public API delegation to specialized modules
- Module coordination and dependency injection
- Backward compatibility layer

#### Detector Module (`lua/monava/core/detector.lua`)
**Purpose**: Centralized monorepo type detection logic
**Interface**:
```lua
detector.detect_type(path) -> string|nil, table|nil
detector.register_type(name, detector_config) -> boolean
detector.get_supported_types() -> table
```

#### Parser Modules (`lua/monava/core/parsers/`)
**Purpose**: Format-specific parsing separated by type
**Base Parser** (`parsers/base.lua`):
```lua
-- Common interface all parsers implement
base.create_parser(config) -> parser_instance
parser:get_packages(root_path) -> packages[], error|nil
parser:validate_workspace(path) -> boolean, error|nil
```

#### Resource Manager (`lua/monava/core/resource_manager.lua`)
**Purpose**: Centralized cleanup of file handles, processes, timers
**Interface**:
```lua
resource_manager.register_resource(id, cleanup_fn) -> void
resource_manager.cleanup_all() -> void
resource_manager.cleanup_by_type(type) -> void
```

### 4. Enhanced Async Module (`lua/monava/utils/async.lua`)

#### Purpose
Replace current unlimited async operations with bounded concurrency

#### Interface
```lua
async.run_with_limit(cmd, callback, opts) -> handle|nil
async.set_max_concurrency(limit) -> void
async.cancel_operation(handle) -> boolean
async.cleanup_all() -> void
```

#### Concurrency Control
- **Semaphore**: Limit to 10 concurrent operations
- **Queue**: Queue excess operations for later execution
- **Cancellation**: Allow users to cancel long-running operations
- **Cleanup**: Guaranteed resource cleanup on completion/cancellation

## Phase 3 Components (Advanced Features)

### 5. Enhanced Cache Manager (`lua/monava/core/cache_manager.lua`)

#### Purpose
Replace unbounded cache with LRU eviction and size monitoring

#### Interface
```lua
cache_manager.set_max_size(bytes) -> void
cache_manager.get_memory_usage() -> number
cache_manager.evict_lru(count) -> number
cache_manager.monitor_memory() -> void
```

#### Features
- **LRU Eviction**: Remove least recently used entries when limit reached
- **Memory Monitoring**: Track actual memory usage, not just entry count
- **Size Limits**: Configurable memory limits with smart defaults
- **Statistics**: Cache hit/miss rates for performance tuning

### 6. Binary File Detection (`lua/monava/utils/fs.lua` enhancement)

#### Purpose
Prevent crashes when encountering binary files

#### Implementation
```lua
-- Add to read_file function
local function is_binary_file(content)
  -- Check for null bytes (common in binary files)
  if content:find('\0') then return true end
  
  -- Check for JSON/text magic numbers
  local trimmed = content:match("^%s*(.)")
  if not trimmed or not trimmed:match("[%[%{%w%-%"]") then
    return true
  end
  
  return false
end
```

## Integration Strategy

### Backward Compatibility Layer
- **API Preservation**: All existing function signatures unchanged
- **Gradual Migration**: Internal calls migrated to new modules incrementally
- **Fallback Mechanisms**: New modules fall back to old behavior on errors

### Dependency Injection Pattern
```lua
-- Core init coordinates dependencies
local core = {
  detector = require("monava.core.detector"),
  cache_manager = require("monava.core.cache_manager"),
  resource_manager = require("monava.core.resource_manager"),
}

-- Modules receive dependencies instead of importing directly
function core.get_packages(package_name)
  local valid, err = validation.validate_package_name(package_name)
  if not valid then
    errors.notify_error(errors.CODES.INVALID_INPUT, err)
    return
  end
  
  return core.detector.get_packages(package_name, {
    cache = core.cache_manager,
    resources = core.resource_manager,
  })
end
```

### Migration Path
1. **Phase 1**: Add validation and error handling (no breaking changes)
2. **Phase 2**: Create new modules alongside existing core (parallel development)
3. **Phase 3**: Migrate functions from old core to new modules (one at a time)
4. **Phase 4**: Remove old core module once all functions migrated

This comprehensive design addresses both immediate MEMORY.md priorities and critical architectural issues identified in the code review, providing a solid foundation for future plugin development.