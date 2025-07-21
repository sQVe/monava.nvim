# monava.nvim

🚀 **Modern Monorepo Navigation for Neovim**

A Neovim plugin that provides intelligent navigation and management for monorepos, supporting multiple picker backends (Telescope, fzf-lua, snacks.nvim) and various monorepo types.

## 🎯 Features

- **Multi-Picker Support**: Works with Telescope, fzf-lua, and snacks.nvim
- **Intelligent Detection**: Automatically detects monorepo type and packages
- **Fast Navigation**: Quick switching between packages and scoped file search
- **Dependency Awareness**: Navigate package dependencies easily
- **Performance Optimized**: Caching system for large repositories
- **Extensible**: Modular architecture for adding new monorepo types

## 🏗️ Supported Monorepo Types

### Tier 1 (Implemented)

- **JavaScript/TypeScript**: NPM/Yarn/PNPM workspaces, Nx, Lerna
- **Rust**: Cargo workspaces

### Tier 2 (Planned)

- **Python**: Poetry monorepos
- **Go**: Multi-module repositories
- **Java**: Gradle/Maven multi-module

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'sqve/monava.nvim',
  dependencies = {
    -- One of these pickers (you don't need all of them)
    'nvim-telescope/telescope.nvim',  -- Most popular
    'ibhagwan/fzf-lua',              -- High performance
    'folke/snacks.nvim',             -- Modern all-in-one
  },
  config = function()
    require('monava').setup({
      -- Optional configuration
      debug = false,
      picker_priority = { 'telescope', 'fzf-lua', 'snacks' },
    })
  end,
}
```

### Using other plugin managers

<details>
<summary>packer.nvim</summary>

```lua
use {
  'sqve/monava.nvim',
  requires = {
    'nvim-telescope/telescope.nvim', -- or other supported pickers
  },
  config = function()
    require('monava').setup()
  end
}
```

</details>

## ⚡ Usage

### Commands

- `:Monava packages` - List all packages in the monorepo
- `:Monava switch` - Switch to a different package
- `:Monava files [package]` - Find files within a package
- `:Monava dependencies [package]` - Show package dependencies
- `:Monava info` - Display monorepo information

### Short alias

- `:Mp packages` - Alias for `:Monava packages`

### Default Keymaps

```lua
vim.keymap.set('n', '<leader>mp', '<cmd>Monava packages<cr>', { desc = 'Monava: packages' })
vim.keymap.set('n', '<leader>ms', '<cmd>Monava switch<cr>', { desc = 'Monava: switch' })
vim.keymap.set('n', '<leader>mf', '<cmd>Monava files<cr>', { desc = 'Monava: files' })
vim.keymap.set('n', '<leader>md', '<cmd>Monava dependencies<cr>', { desc = 'Monava: dependencies' })
vim.keymap.set('n', '<leader>mi', '<cmd>Monava info<cr>', { desc = 'Monava: info' })
```

## ⚙️ Configuration

<details>
<summary>Default Configuration</summary>

```lua
require('monava').setup({
  -- Debug mode
  debug = false,

  -- Picker preferences (in order of preference)
  picker_priority = { 'telescope', 'fzf-lua', 'snacks' },

  -- Cache settings
  cache = {
    enabled = true,
    ttl = 300, -- 5 minutes
  },

  -- Detection settings
  detection = {
    max_depth = 3,
    patterns = {
      javascript = { 'package.json', 'nx.json', 'lerna.json' },
      rust = { 'Cargo.toml' },
      python = { 'pyproject.toml', 'poetry.lock' },
      -- ... more patterns
    },
  },

  -- Keymaps (set to false to disable)
  keymaps = {
    packages = '<leader>mp',
    switch = '<leader>ms',
    files = '<leader>mf',
    dependencies = '<leader>md',
    info = '<leader>mi',
  },
})
```

</details>

## 🩺 Health Check

Run `:checkhealth monava` to verify:

- Neovim version compatibility
- Available picker backends
- Monorepo detection in current directory

## 🚧 Development Status

**Current Phase**: Foundation Complete ✅

- [x] Plugin structure and architecture
- [x] Configuration system
- [x] Multi-picker abstraction layer
- [x] Utility modules and caching
- [x] User commands and keymaps
- [ ] Core monorepo detection (In Progress)
- [ ] Picker implementations
- [ ] Package navigation features

## 🤝 Contributing

Contributions are welcome! This plugin is in active development.

### Development Setup

1. Clone the repository
2. Run tests: `./scripts/test`
3. Follow the established patterns in `lua/monava/`

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

Inspired by existing monorepo tools and the Neovim community's excellent plugin ecosystem.
