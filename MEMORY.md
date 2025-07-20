# Project Memory Documentation

## Research & Planning Phase - 2025-01-20 15:30

### Context
Conducted comprehensive research for creating a Neovim plugin called "monava.nvim" for monorepo navigation. Project started with feasibility analysis and ended with approved implementation plan supporting multiple picker backends (telescope, fzf-lua, snacks.nvim).

### Key Decisions
- **Multi-picker support**: Support telescope.nvim, fzf-lua, and snacks.nvim instead of single picker to maximize adoption
- **Picker-agnostic architecture**: Core logic separated from UI layer using adapter pattern
- **Phased approach**: Start with JavaScript/TypeScript monorepos (highest demand) then expand to other languages
- **Modular detection system**: Support multiple monorepo types through pluggable detectors
- **Performance focus**: Leverage fzf-lua for large repo performance, implement caching for package discovery

### Implementation Patterns
- **Plugin structure**: lua/monava/ with core/, adapters/, and utils/ subdirectories
- **Detection strategy**: File-based detection using configuration files (package.json, nx.json, lerna.json, etc.)
- **Abstraction layer**: Picker adapters provide consistent interface regardless of backend
- **Auto-detection**: Automatically detect available pickers with graceful fallbacks

### Research Findings
- **Existing solutions**: monorepo.nvim (basic), neoscopes (NPM only) - significant gap exists
- **Monorepo types to support**: 
  - Tier 1: NPM/Yarn/PNPM workspaces, Nx, Lerna
  - Tier 2: Cargo workspaces, Poetry, Rush
  - Tier 3: Go modules, Java Gradle/Maven, Bazel
- **User demand**: High for JavaScript/TypeScript, growing for Rust and Python
- **Technical feasibility**: Neovim Lua API well-suited, Telescope extension development documented

### Lessons Learned
- **Market analysis crucial**: Understanding existing solutions revealed clear opportunity
- **Multi-backend support**: Essential for wide adoption in diverse Neovim ecosystem
- **Start narrow, expand**: Focus on JavaScript/TypeScript first prevents over-engineering
- **Performance matters**: Large monorepos need fast navigation, fzf-lua provides this

### Next Steps
- [ ] Set up basic plugin directory structure
- [ ] Create main plugin entry point (init.lua)
- [ ] Implement picker detection and abstraction layer
- [ ] Build monorepo detection system for JavaScript/TypeScript
- [ ] Create package discovery and caching system
- [ ] Implement basic Telescope adapter
- [ ] Add fzf-lua adapter
- [ ] Add snacks.nvim adapter

### Technical Architecture
```
lua/monava/
├── init.lua              # Main entry point
├── config.lua           # Configuration management
├── core/                # Picker-agnostic logic
│   ├── detection.lua    # Monorepo detection
│   ├── packages.lua     # Package management
│   └── navigation.lua   # Navigation logic
├── adapters/            # Picker-specific implementations
│   ├── telescope.lua    # Telescope integration
│   ├── fzf_lua.lua     # fzf-lua integration
│   └── snacks.lua      # snacks.nvim integration
└── utils/              # Helper functions
```

### Success Criteria
- Handle 80% of common monorepo setups automatically
- Sub-100ms navigation in repos with <1000 packages
- Seamless integration with existing Neovim workflow
- Active community adoption and contribution

## Implementation Review & Support Analysis - 2025-01-20 16:45

### Context
Conducted comprehensive review of completed monava.nvim implementation to understand actual functionality. User reported plugin showing "Monorepo Type: Unknown" and "Packages Found: 0" for all their repositories, leading to discovery of significant gaps between documented and actual support. Analysis revealed implementation vs. documentation drift and incomplete feature implementations.

### Key Decisions Made
- **Accurate support documentation**: Created definitive mapping of fully supported vs. partially supported vs. missing monorepo types
- **Corrected false claims**: Fixed incorrect statements about Go modules support (not implemented at all)
- **Prioritized gap analysis**: Identified PNPM, Rush, Poetry as having detection but missing proper package discovery
- **Established testing strategy**: Recommended specific open-source repositories for validation testing

### Implementation Patterns Discovered
- **Fallback pattern overuse**: Many detectors fall back to NPM workspace parsing instead of implementing proper format-specific parsers
- **Detection vs. Implementation gap**: Framework detects file patterns (pnpm-workspace.yaml, rush.json) but lacks corresponding parsing logic
- **Partial support architecture**: Robust detection system exists but specific format parsers are placeholder implementations
- **Three-tier support model**: Fully working (NPM/Yarn/Nx/Cargo) → Partial (PNPM/Rush/Poetry) → Missing (Go/Java/Maven)

### Lessons Learned
- **Implementation validation critical**: Need systematic testing with real repositories, not just theoretical code review
- **Documentation drift dangerous**: Claims about support must be validated against actual working functionality
- **User feedback reveals reality gaps**: Plugin appeared feature-complete but failed real-world usage scenarios
- **Fallback implementations misleading**: Using NPM parsing for PNPM/Rush gives false sense of completion
- **Language ecosystem complexity**: Each monorepo type needs dedicated parser, generic fallbacks insufficient

### Current Accurate Support Status
**✅ Fully Working:**
- NPM Workspaces (package.json workspaces field parsing)
- Yarn Workspaces (same as NPM, compatible format)
- Nx Monorepos (apps/, libs/, packages/ directory scanning)
- Cargo Workspaces (Cargo.toml [workspace] member parsing)

**⚠️ Partial/Broken:**
- PNPM Workspaces (detects pnpm-workspace.yaml but falls back to NPM parsing)
- Rush (detects rush.json but no package discovery implementation)
- Lerna (detects lerna.json but falls back to NPM parsing)
- Poetry (detects pyproject.toml but empty package discovery)

**❌ Not Supported:**
- Go modules/workspaces (no detection or parsing)
- Maven multi-module (no detection or parsing)
- Gradle multi-project (no detection or parsing)
- Bazel workspaces (no detection or parsing)

### Next Steps
**Priority 1 - Fix Existing Partial Support:**
- [ ] Implement proper pnpm-workspace.yaml parsing for PNPM workspaces
- [ ] Implement rush.json parsing for Rush monorepos  
- [ ] Implement Poetry pyproject.toml workspace discovery
- [ ] Test implementations with real-world repositories

**Priority 2 - Add Missing Language Support:**
- [ ] Implement Go modules detection and workspace parsing
- [ ] Add Maven multi-module detection and parsing
- [ ] Add Gradle multi-project detection and parsing

**Priority 3 - Validation and Testing:**
- [ ] Test with recommended repositories (React Hook Form, Storybook, Babel)
- [ ] Create automated test suite with real monorepo examples
- [ ] Update README with accurate support matrix

**Priority 4 - User Experience:**
- [ ] Improve error messages when monorepo type unsupported
- [ ] Add debug mode for troubleshooting detection failures
- [ ] Create migration guide for unsupported repository types

## Adapter Architecture Analysis - 2025-07-20 15:45

### Context
Conducted comprehensive analysis of adapter architecture to understand implementation gap between documented modular design and actual monolithic implementation. Discovered significant architectural inconsistencies that need refactoring to align with intended design and test expectations.

### Key Decisions Made
- **Identified critical architecture gap**: Current `adapters/init.lua` contains 550+ lines of monolithic code instead of documented modular structure
- **Confirmed test-driven approach**: Tests expect modular API with `create_package_picker()`, `show_package_picker()`, `select_picker()`, configuration methods
- **Prioritized breaking changes**: Since backward compatibility not required, can implement clean modern architecture
- **Established refactoring plan**: Split monolithic file into proper adapter modules with standardized interface

### Implementation Patterns Discovered
- **Monolithic adapter system**: Single 550-line file handling all picker implementations with embedded picker-specific code
- **Inconsistent API design**: Tests expect `get_available_pickers()` to return table with boolean values, but implementation returns array
- **Missing modular interfaces**: No separate `telescope.lua`, `fzf_lua.lua`, `snacks.lua` adapter files as documented
- **Complex fallback chains**: Each operation tries active picker → all available pickers → built-in fallback
- **Test expectations mismatch**: Tests expect `mini.pick` support, configuration merging, and methods not implemented

### Architecture Problems Identified
1. **Monolithic Structure**: All adapter code in single file contradicts documented modular design
2. **API Inconsistencies**: Return types don't match test expectations (array vs table with booleans)
3. **Missing Methods**: Tests expect `create_package_picker()`, `merge_configs()`, `validate_config()` methods
4. **Missing Adapters**: `mini.pick` support referenced in tests but not implemented
5. **Code Duplication**: Similar picker patterns repeated for each backend instead of shared utilities

### Current Implementation Analysis
**✅ Working Features:**
- Picker detection and availability checking
- Fallback chain execution (active → available → built-in)
- Basic Telescope, fzf-lua, snacks.nvim integration
- Error handling with pcall protection
- Configuration override support

**❌ Architecture Issues:**
- Monolithic file structure contradicts documented design
- API methods don't match test expectations
- Missing mini.pick adapter completely
- No configuration validation or merging utilities
- Duplicated picker patterns across implementations

### Lessons Learned
- **Documentation vs Implementation**: Major gap between architectural documentation and actual code structure
- **Test-driven architecture**: Tests reveal intended API design better than existing implementation
- **Modular design benefits**: Current monolithic approach makes maintenance and extension difficult
- **Configuration complexity**: Each picker needs consistent configuration merging and validation
- **Interface standardization**: Need common adapter interface to reduce code duplication

### Next Steps
**Phase 1 - Modular Architecture (High Priority):**
- [ ] Create separate `adapters/telescope.lua` with standardized interface
- [ ] Create separate `adapters/fzf_lua.lua` with standardized interface  
- [ ] Create separate `adapters/snacks.lua` with standardized interface
- [ ] Add `adapters/mini_pick.lua` support as expected by tests
- [ ] Refactor `adapters/init.lua` to registry and orchestration only

**Phase 2 - API Alignment (High Priority):**
- [ ] Implement `create_package_picker()` method expected by tests
- [ ] Implement `show_package_picker()` method with proper signature
- [ ] Add `get_default_configs()`, `merge_configs()`, `validate_config()` methods
- [ ] Fix `get_available_pickers()` return type to match test expectations

**Phase 3 - Code Quality (Medium Priority):**
- [ ] Extract common picker patterns into shared utilities
- [ ] Standardize error handling across all adapters
- [ ] Create adapter base class/interface for consistency
- [ ] Update tests to match new modular architecture

### Implementation Strategy
- **Breaking changes allowed**: No backward compatibility constraints
- **Test-first approach**: Align implementation with test expectations
- **Modular design**: Each adapter in separate file with common interface
- **Performance maintenance**: Keep sub-100ms picker creation for 1000+ packages
- **Clean abstractions**: Separate picker-specific logic from orchestration