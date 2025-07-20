-- lua/monava/config.lua
-- Configuration management for monava plugin.

local M = {}

-- Default configuration.
local default_config = {
  -- Debug mode.
  debug = false,

  -- Picker preferences (in order of preference).
  picker_priority = { "telescope", "fzf-lua", "snacks" },

  -- Cache settings.
  cache = {
    enabled = true,
    ttl = 300, -- 5 minutes.
  },

  -- Detection settings.
  detection = {
    -- Maximum depth to search for package files.
    max_depth = 3,

    -- File patterns to look for in package detection.
    patterns = {
      javascript = {
        "package.json",
        "nx.json",
        "lerna.json",
        "rush.json",
        "pnpm-workspace.yaml",
        "yarn.lock",
      },
      rust = {
        "Cargo.toml",
      },
      python = {
        "pyproject.toml",
        "poetry.lock",
      },
      go = {
        "go.mod",
      },
      java = {
        "build.gradle",
        "build.gradle.kts",
        "pom.xml",
      },
    },
  },

  -- UI settings.
  ui = {
    -- Default window size for info display.
    window_height = 20,

    -- Icons for different package types (if available).
    icons = {
      javascript = "󰌞",
      typescript = "󰛦",
      rust = "",
      python = "",
      go = "",
      java = "",
      unknown = "",
    },
  },

  -- Picker-specific configurations.
  pickers = {
    telescope = {
      theme = "dropdown",
      layout_config = {
        height = 0.4,
        width = 0.8,
      },
    },
    ["fzf-lua"] = {
      winopts = {
        height = 0.4,
        width = 0.8,
      },
    },
    snacks = {
      win = {
        height = 0.4,
        width = 0.8,
      },
    },
  },

  -- Keymaps (can be disabled by setting to false).
  keymaps = {
    -- Global keymaps.
    packages = "<leader>mp",
    switch = "<leader>ms",
    files = "<leader>mf",
    dependencies = "<leader>md",
    info = "<leader>mi",
  },

  -- Monorepo-specific settings.
  monorepo = {
    -- Auto-detect current package based on file location.
    auto_detect_package = true,

    -- Include hidden directories in package search.
    include_hidden = false,

    -- Exclude patterns for package discovery.
    exclude_patterns = {
      "node_modules",
      ".git",
      "target",
      "dist",
      "build",
      "__pycache__",
      ".venv",
      "venv",
    },
  },
}

-- Merge user configuration with defaults.
function M.merge_config(user_config)
  user_config = user_config or {}

  local config = M._create_config_copy()
  return M._perform_deep_merge(config, user_config)
end

-- Create a copy of the default configuration.
function M._create_config_copy()
  if vim and vim.deepcopy then
    return vim.deepcopy(default_config)
  else
    -- Use our fallback deep copy for testing.
    return M.get_default_config()
  end
end

-- Perform deep merge of user config into target config.
function M._perform_deep_merge(target, source)
  for key, value in pairs(source) do
    if M._should_merge_tables(value, target[key]) then
      target[key] = M._perform_deep_merge(target[key], value)
    else
      target[key] = value
    end
  end
  return target
end

-- Check if two values should be merged as tables.
function M._should_merge_tables(source_value, target_value)
  return type(source_value) == "table" and type(target_value) == "table"
end

-- Validate configuration.
function M.validate_config(config)
  local issues = {}

  -- Validate picker priority.
  if config.picker_priority and type(config.picker_priority) ~= "table" then
    table.insert(issues, "picker_priority must be a table")
  end

  -- Validate cache TTL.
  local cache_ttl = config.cache.ttl
  if cache_ttl and (type(cache_ttl) ~= "number" or cache_ttl < 0) then
    table.insert(issues, "cache.ttl must be a positive number")
  end

  -- Validate detection max_depth.
  local max_depth = config.detection.max_depth
  if max_depth and (type(max_depth) ~= "number" or max_depth < 1) then
    table.insert(issues, "detection.max_depth must be a positive number")
  end

  if #issues > 0 then
    vim.notify(
      "[monava] Configuration issues:\n" .. table.concat(issues, "\n"),
      vim.log.levels.WARN
    )
  end

  return #issues == 0
end

-- Get default configuration (for reference).
function M.get_default_config()
  if vim and vim.deepcopy then
    return vim.deepcopy(default_config)
  else
    -- Fallback for testing without Neovim.
    local function deep_copy(orig)
      local copy
      if type(orig) == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
          copy[deep_copy(orig_key)] = deep_copy(orig_value)
        end
        setmetatable(copy, deep_copy(getmetatable(orig)))
      else
        copy = orig
      end
      return copy
    end
    return deep_copy(default_config)
  end
end

-- Setup keymaps based on configuration.
function M.setup_keymaps(config)
  if not config.keymaps then
    return
  end

  local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.silent = opts.silent ~= false
    opts.noremap = opts.noremap ~= false
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  -- Set up global keymaps.
  for action, keymap in pairs(config.keymaps) do
    if keymap and keymap ~= false then
      local cmd = "<cmd>Monava " .. action .. "<cr>"
      local desc = "Monava: " .. action

      map("n", keymap, cmd, { desc = desc })
    end
  end
end

-- Get configuration for a specific picker.
function M.get_picker_config(config, picker_name)
  return config.pickers[picker_name] or {}
end

-- Check if a feature is enabled.
function M.is_enabled(config, feature_path)
  local current = config
  for segment in feature_path:gmatch("[^%.]+") do
    if type(current) ~= "table" or current[segment] == nil then
      return false
    end
    current = current[segment]
  end
  return current ~= false
end

return M
