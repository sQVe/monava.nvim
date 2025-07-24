# Foundation Fixes - Requirements

## Overview
Address critical foundation issues identified in MEMORY.md priorities PLUS comprehensive code review findings to establish a solid architectural foundation for future development. This spec covers both immediate input validation/error handling needs and critical architectural threats that could block plugin growth.

## Requirements

### Requirement 1: Enhanced Input Validation
**User Story:** As a plugin user, I want proper validation of function parameters, so that I receive clear error messages instead of crashes when I provide invalid input.

#### Acceptance Criteria
1. WHEN I call `M.files()` with nil parameter THEN system SHALL display error "Package name cannot be nil"
2. WHEN I call `M.files()` with empty string THEN system SHALL display error "Package name cannot be empty"  
3. WHEN I call `M.files()` with invalid package name format THEN system SHALL display error "Invalid package name format"
4. WHEN I call `M.dependencies()` with invalid parameter THEN system SHALL validate input before processing
5. IF package name exceeds 255 characters THEN system SHALL reject with "Package name too long"
6. IF package name contains invalid characters THEN system SHALL validate against regex pattern `^[%w@][%w@%-%./]*$`

### Requirement 2: Standardized Error Messages  
**User Story:** As a plugin user, I want consistent error message formatting, so that I can easily understand and debug issues across all plugin functions.

#### Acceptance Criteria
1. WHEN any error occurs THEN system SHALL display error with format "[monava:{ERROR_CODE}] {message}"
2. WHEN error has additional details THEN system SHALL append "Details: {details}" on new line
3. IF error is critical THEN system SHALL use vim.log.levels.ERROR level
4. WHEN validation fails THEN system SHALL use error code "E001" 
5. WHEN monorepo detection fails THEN system SHALL use error code "E002"
6. WHEN picker operation fails THEN system SHALL use error code "E003"
7. WHEN cache operation fails THEN system SHALL use error code "E004"

### Requirement 3: Core Architecture Decomposition
**User Story:** As a developer maintaining the plugin, I want the monolithic 898-line core module split into focused components, so that I can safely modify, test, and extend specific functionality without risking the entire system.

#### Acceptance Criteria
1. WHEN core module is split THEN system SHALL have separate detector, parsers, and cache modules
2. WHEN I modify PNPM parsing THEN system SHALL not affect Nx or Cargo detection
3. WHEN I add new monorepo type THEN system SHALL only require changes to detector module
4. WHEN I run tests THEN system SHALL allow unit testing of individual components
5. IF core module exceeds 300 lines THEN system SHALL be further decomposed
6. WHEN modules communicate THEN system SHALL use clear interfaces, not direct imports

### Requirement 4: Resource Management & Reliability  
**User Story:** As a plugin user in long Neovim sessions, I want guaranteed cleanup of system resources, so that the plugin doesn't cause memory leaks or system instability.

#### Acceptance Criteria
1. WHEN async operations complete THEN system SHALL close all file handles and pipes
2. WHEN plugin processes crash THEN system SHALL cleanup orphaned resources
3. WHEN cache grows large THEN system SHALL enforce size limits with LRU eviction
4. WHEN multiple repos accessed THEN system SHALL prevent resource exhaustion
5. IF binary files encountered THEN system SHALL detect and skip without crashing
6. WHEN operations timeout THEN system SHALL cancel and cleanup gracefully

### Requirement 5: Performance & Scalability Safeguards
**User Story:** As a user of large monorepos, I want the plugin to remain responsive and not overwhelm my system, so that I can navigate efficiently even in 1000+ package repositories.

#### Acceptance Criteria
1. WHEN discovering packages THEN system SHALL limit concurrent operations to 10 maximum
2. WHEN processing glob patterns THEN system SHALL cache compiled patterns
3. WHEN cache size exceeds limit THEN system SHALL evict oldest entries
4. WHEN operations take >30 seconds THEN system SHALL provide cancellation option
5. IF repository has >1000 packages THEN system SHALL stream results progressively
6. WHEN patterns repeat THEN system SHALL reuse compiled regex instead of recompiling

## Technical Constraints
- Must work with Neovim 0.8+ (existing requirement)
- Cannot break existing public API surface
- Should add minimal overhead to function calls
- Must integrate with existing vim.notify error handling
- Should follow existing code style and patterns
- Core module split must preserve all existing functionality
- Resource management must not interfere with Neovim's event loop
- Performance safeguards must not break existing workflows
- All changes must be incrementally deployable

## Success Criteria

### Phase 1: Input Validation & Error Handling (MEMORY.md Priorities)
- [ ] `M.files("invalid_name")` shows proper error message with code
- [ ] All existing tests continue to pass
- [ ] New validation prevents 90% of user input errors
- [ ] Error messages are consistent across all plugin functions
- [ ] Zero performance regression in happy path scenarios

### Phase 2: Core Architecture Decomposition
- [ ] Core module split into <300 line focused modules
- [ ] All existing functionality preserved after split
- [ ] Unit tests possible for individual components
- [ ] New monorepo types can be added without touching core logic
- [ ] Module dependencies clearly defined with interfaces

### Phase 3: Resource Management & Reliability
- [ ] No file handle or process leaks in long sessions
- [ ] Binary file crashes eliminated with proper detection
- [ ] Cache memory usage bounded with LRU eviction
- [ ] Async operations properly cancelled and cleaned up
- [ ] Plugin remains stable under system resource pressure

### Phase 4: Performance & Scalability
- [ ] Concurrent async operations limited to prevent system overload
- [ ] Glob pattern compilation cached for repeated operations
- [ ] Large repositories (1000+ packages) handled without freezing
- [ ] Progressive loading implemented for massive monorepos
- [ ] String operations optimized to eliminate redundant work

## Implementation Priority
1. **IMMEDIATE** (Phase 1): Input validation and error handling (MEMORY.md priorities)
2. **HIGH** (Phase 2): Core architecture decomposition (enables all other improvements)
3. **MEDIUM** (Phase 3): Resource management and reliability fixes
4. **MEDIUM** (Phase 4): Performance and scalability enhancements
