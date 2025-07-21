# Contributing

## Quick Start

1. Fork and clone the repository
2. Install dependencies: `luarocks install busted && cargo install stylua && luarocks install luacheck`
3. Install hooks: `./scripts/install-hooks`
4. Run tests: `./scripts/test`

## Development

### Quality Checks

```bash
make check    # Run all checks (required before commits)
make test     # Run tests only
make lint     # Run linting only
make format   # Format code
```

### Workflow

1. Create branch: `git checkout -b feature/name`
2. Use conventional commits: `feat:`, `fix:`, `docs:`, `test:`
3. All contributions must include tests
4. Pre-commit hooks handle formatting and linting

### Test Pattern

```lua
local helpers = require('tests.helpers')

describe('module', function()
  after_each(function()
    helpers.fs_rm() -- Always cleanup
  end)

  it('should work', function()
    local workspace = helpers.fs_create({
      ['package.json'] = '{"name": "test"}'
    })
    assert.are.equal('expected', actual)
  end)
end)
```

## Architecture

```
lua/monava/
├── init.lua       # Public API
├── config.lua     # Configuration
├── core/          # Core logic
├── adapters/      # Picker implementations
└── utils/         # Utilities
```

## Adding Support

### New Monorepo Type

1. Add detection patterns in `config.lua`
2. Implement parser in `core/init.lua`
3. Write tests with real examples
4. Update documentation

### New Picker

1. Create `adapters/picker_name.lua`
2. Implement interface: `is_available()`, `show_packages()`, `switch_package()`, `find_files()`
3. Register in `adapters/init.lua`
4. Add tests

## Bug Reports

Include:

- Neovim version (`nvim --version`)
- Steps to reproduce
- Expected vs actual behavior
- Minimal config to reproduce

## PR Requirements

- [ ] Tests pass (`make check`)
- [ ] Tests included for new functionality
- [ ] Documentation updated if needed
- [ ] Conventional commit messages
