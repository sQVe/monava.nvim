# Foundation Fixes - Implementation Tasks

## Overview
This task breakdown covers both MEMORY.md immediate priorities AND comprehensive architectural improvements identified in code review. Tasks are organized by phase for systematic implementation.

## Phase 1: Immediate Fixes (MEMORY.md Priorities - 3 hours)

- [x] 1. Create validation utility module
  - Create `lua/monava/utils/validation.lua` with package name validation function
  - Implement regex validation pattern `^[%w@][%w@%-%./]*$`
  - Add nil, empty string, and length validation (max 255 chars)
  - _Leverage: lua/monava/config.lua validation patterns, lua/monava/utils/init.lua module structure_
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6_

- [x] 2. Create standardized error handling module  
  - Create `lua/monava/utils/errors.lua` with error codes and notification function
  - Define ERROR_CODES: E001 (invalid input), E002 (no monorepo), E003 (picker failed), E004 (cache error)
  - Implement notify_error function with format "[monava:{code}] {message}"
  - _Leverage: existing vim.notify patterns throughout codebase_
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7_

- [ ] 3. Add validation to M.files() function
  - Update `lua/monava/init.lua` line 166 to add package name validation
  - Import validation module and call validate_package_name()
  - Handle validation failure with early return and error notification
  - _Leverage: existing function structure and error handling patterns_
  - _Requirements: 1.1, 1.2, 1.3, 3.1_

- [ ] 4. Add validation to M.dependencies() function
  - Update `lua/monava/init.lua` line 194 to add input validation
  - Apply same validation pattern as M.files()
  - Ensure consistent error messaging
  - _Leverage: validation module from task 1, error module from task 2_
  - _Requirements: 1.4, 2.1, 3.1_

- [ ] 5. Create comprehensive validation tests
  - Create `tests/utils/validation_spec.lua` for validation function testing
  - Test valid package names, invalid formats, nil values, empty strings, length limits
  - Verify error messages match expected format
  - _Leverage: existing test patterns in tests/ directory, BDD-style testing approach_
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6_

- [ ] 6. Create error handling tests
  - Create `tests/utils/errors_spec.lua` for error formatting testing
  - Test error code formatting, message structure, details appendage
  - Verify vim.notify integration and log levels
  - _Leverage: existing test helper functions and mocking patterns_
  - _Requirements: 2.1, 2.2, 2.3_

- [ ] 7. Update existing error messages to use standardized format
  - Replace ad-hoc error messages in main functions with error codes
  - Update core monorepo detection errors to use E002
  - Update picker failures to use E003
  - _Leverage: new errors.lua module, existing error handling locations_
  - _Requirements: 2.4, 2.5, 2.6, 2.7_

- [ ] 8. Integration testing and backward compatibility verification
  - Run existing test suite to ensure no regressions
  - Test that `M.files("invalid_name")` shows proper error message
  - Verify all success criteria from requirements are met
  - _Leverage: existing comprehensive test suite_
  - _Requirements: 6.1, 6.2, 6.4_

## Phase 2: Core Architecture Decomposition (1-2 weeks)

### Critical Foundation Threats

- [ ] 9. Create core module detector
  - Extract monorepo detection logic from `lua/monava/core/init.lua` lines 15-107
  - Create `lua/monava/core/detector.lua` with clean detection interface
  - Implement detector registration system for extensibility
  - _Leverage: existing detection patterns, pcall error handling_
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 10. Create PNPM parser module
  - Extract `_get_pnpm_packages()` function (130+ lines) into dedicated parser
  - Create `lua/monava/core/parsers/pnpm.lua` with focused responsibility
  - Implement common parser interface defined in design
  - _Leverage: existing YAML parsing logic, glob expansion utilities_
  - _Requirements: 3.1, 3.2, 3.4_

- [ ] 11. Create NPM parser module
  - Extract `_get_npm_packages()` function into dedicated parser
  - Create `lua/monava/core/parsers/npm.lua` with workspace detection
  - Follow same interface pattern as PNPM parser
  - _Leverage: existing JSON parsing, workspace detection logic_
  - _Requirements: 3.1, 3.2, 3.4_

- [ ] 12. Create Nx parser module
  - Extract `_get_nx_packages()` function into dedicated parser
  - Create `lua/monava/core/parsers/nx.lua` with Nx-specific logic
  - Maintain compatibility with existing Nx workspace detection
  - _Leverage: existing Nx detection patterns_
  - _Requirements: 3.1, 3.2, 3.4_

- [ ] 13. Create Cargo parser module
  - Extract `_get_cargo_packages()` and related functions into dedicated parser
  - Create `lua/monava/core/parsers/cargo.lua` with TOML parsing
  - Include workspace member extraction and package discovery
  - _Leverage: existing TOML parsing logic, member extraction functions_
  - _Requirements: 3.1, 3.2, 3.4_

- [ ] 14. Create parser base utilities
  - Create `lua/monava/core/parsers/base.lua` with common parser interface
  - Define standard parser contract: validate_workspace, get_packages, etc.
  - Implement shared utilities for package metadata and dependency handling
  - _Leverage: common patterns from existing parsers_
  - _Requirements: 3.1, 3.4, 3.6_

- [ ] 15. Create resource manager module
  - Create `lua/monava/core/resource_manager.lua` for centralized cleanup
  - Track file handles, processes, timers across all operations
  - Implement guaranteed cleanup on plugin exit or error
  - _Leverage: existing vim.loop resource usage patterns_
  - _Requirements: 4.1, 4.2, 4.6_

- [ ] 16. Refactor core init to coordinator role
  - Reduce `lua/monava/core/init.lua` from 898 lines to <100 lines
  - Transform to coordination layer between specialized modules
  - Maintain all existing public API functions with same signatures
  - _Leverage: new detector, parser modules, resource manager_
  - _Requirements: 3.1, 3.6, 6.1, 6.5, 6.6_

### Resource Management & Reliability

- [ ] 17. Add binary file detection to fs utilities
  - Enhance `lua/monava/utils/fs.lua` read_file() with binary detection
  - Add magic number checking for JSON/text files vs binary
  - Prevent crashes when encountering binary package.json files
  - _Leverage: existing file reading patterns, error handling_
  - _Requirements: 4.5_

- [ ] 18. Create enhanced async module with concurrency limits
  - Create `lua/monava/utils/async.lua` replacing unlimited async operations
  - Implement semaphore-based concurrency limiting (max 10 operations)
  - Add operation queuing and cancellation capabilities
  - _Leverage: existing run_async patterns, vim.loop operations_
  - _Requirements: 5.1, 5.4_

- [ ] 19. Implement cache size limits and LRU eviction
  - Enhance `lua/monava/utils/cache.lua` with memory monitoring
  - Add LRU eviction when cache exceeds configurable size limits
  - Implement cache statistics and memory usage tracking
  - _Leverage: existing cache infrastructure, TTL mechanisms_
  - _Requirements: 4.3, 5.3_

### Performance & Scalability

- [ ] 20. Add glob pattern compilation caching
  - Enhance `lua/monava/utils/init.lua` glob_match() function
  - Cache compiled regex patterns to avoid recompilation
  - Implement pattern cache with LRU eviction
  - _Leverage: existing glob matching logic_
  - _Requirements: 5.2, 5.6_

- [ ] 21. Implement progressive package discovery for large repos
  - Enhance package discovery functions to stream results
  - Add progress callbacks and early termination for 1000+ package repos
  - Implement pagination and result batching
  - _Leverage: existing package discovery patterns_
  - _Requirements: 5.5_

## Phase 3: Advanced Reliability & Testing (1 week)

### Testing Architecture Improvements

- [ ] 22. Separate unit and integration tests
  - Reorganize tests/ directory to separate unit from integration concerns
  - Create focused unit tests for new modular components
  - Add comprehensive mocking for isolated unit testing
  - _Leverage: existing test helpers and BDD patterns_
  - _Requirements: 3.4_

- [ ] 23. Add dependency injection for better testability
  - Implement dependency injection pattern in core coordination layer
  - Allow mocking of detector, parsers, cache, and resource manager
  - Enable isolated testing of individual components
  - _Leverage: new modular architecture_
  - _Requirements: 3.6_

### Path Security & Validation

- [ ] 24. Enhance path validation with symlink resolution
  - Improve `lua/monava/utils/fs.lua` validate_path() function
  - Add vim.fn.resolve() for proper symlink handling
  - Implement robust boundary checking for workspace traversal
  - _Leverage: existing path validation patterns_
  - _Requirements: 4.4_

### Error Recovery & Stability

- [ ] 25. Add operation cancellation and timeout handling
  - Implement cancellation tokens for long-running operations
  - Add timeout mechanisms with graceful degradation
  - Provide user feedback during long operations
  - _Leverage: new async module, resource manager_
  - _Requirements: 4.6, 5.4_

## Implementation Strategy

### Phase Sequencing
1. **Phase 1** (Immediate - 3 hours): Complete MEMORY.md validation and error handling
2. **Phase 2** (High Priority - 1-2 weeks): Core architecture decomposition and reliability
3. **Phase 3** (Medium Priority - 1 week): Advanced testing and stability features

### Risk Mitigation
- Each task maintains backward compatibility
- Parallel development of new modules alongside existing core
- Incremental migration with fallback mechanisms
- Comprehensive testing at each phase

### Success Validation
- All existing tests continue passing
- New functionality verified with focused unit tests
- Performance benchmarks confirm no regressions
- Memory usage monitored for leak prevention