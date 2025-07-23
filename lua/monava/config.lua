-- lua/monava/config.lua
-- Configuration management for monava plugin.

local M = {}

-- Default configuration.
local default_config = {
  debug = false,

  -- Picker preferences (in order of preference).
  picker_priority = { "telescope", "fzf-lua", "snacks" },

  -- Cache settings.
  cache = {
    enabled = true,
    ttl = 300,
  },

  -- Detection settings.
  detection = {
    max_depth = 3,

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
    window_height = 20,

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

  keymaps = {
    packages = "<leader>mp",
    switch = "<leader>ms",
    files = "<leader>mf",
    dependencies = "<leader>md",
    info = "<leader>mi",
  },

  -- Monorepo-specific settings.
  monorepo = {
    auto_detect_package = true,
    include_hidden = false,
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

-- Enhanced configuration validation with detailed checks
function M.validate_config(config)
  local issues = {}
  local warnings = {}

  -- Validate required structure
  if type(config) ~= "table" then
    table.insert(issues, "Configuration must be a table")
    return false
  end

  -- Validate picker priority
  if config.picker_priority then
    if type(config.picker_priority) ~= "table" then
      table.insert(issues, "picker_priority must be a table")
    else
      local valid_pickers = { "telescope", "fzf-lua", "snacks" }
      for i, picker in ipairs(config.picker_priority) do
        if type(picker) ~= "string" then
          table.insert(issues, "picker_priority[" .. i .. "] must be a string")
        elseif not vim.tbl_contains(valid_pickers, picker) then
          table.insert(warnings, "Unknown picker '" .. picker .. "' in priority list")
        end
      end
    end
  end

  -- Validate cache configuration
  if config.cache then
    if type(config.cache) ~= "table" then
      table.insert(issues, "cache must be a table")
    else
      local cache_ttl = config.cache.ttl
      if cache_ttl ~= nil then
        if type(cache_ttl) ~= "number" then
          table.insert(issues, "cache.ttl must be a number")
        elseif cache_ttl < 0 then
          table.insert(issues, "cache.ttl must be non-negative")
        elseif cache_ttl > 3600 then
          table.insert(warnings, "cache.ttl > 1 hour may cause stale data issues")
        end
      end

      if config.cache.enabled ~= nil and type(config.cache.enabled) ~= "boolean" then
        table.insert(issues, "cache.enabled must be a boolean")
      end
    end
  end

  -- Validate detection configuration
  if config.detection then
    if type(config.detection) ~= "table" then
      table.insert(issues, "detection must be a table")
    else
      local max_depth = config.detection.max_depth
      if max_depth ~= nil then
        if type(max_depth) ~= "number" then
          table.insert(issues, "detection.max_depth must be a number")
        elseif max_depth < 1 then
          table.insert(issues, "detection.max_depth must be at least 1")
        elseif max_depth > 10 then
          table.insert(warnings, "detection.max_depth > 10 may impact performance")
        end
      end
    end
  end

  -- Validate UI configuration
  if config.ui then
    if type(config.ui) ~= "table" then
      table.insert(issues, "ui must be a table")
    else
      if config.ui.window_height ~= nil then
        if type(config.ui.window_height) ~= "number" or config.ui.window_height < 1 then
          table.insert(issues, "ui.window_height must be a positive number")
        end
      end
    end
  end

  -- Validate picker configurations
  if config.pickers then
    if type(config.pickers) ~= "table" then
      table.insert(issues, "pickers must be a table")
    end
  end

  -- Validate keymaps
  if config.keymaps ~= nil and config.keymaps ~= false then
    if type(config.keymaps) ~= "table" then
      table.insert(issues, "keymaps must be a table or false")
    end
  end

  -- Report issues and warnings
  if #issues > 0 then
    vim.notify(
      "[monava] Configuration errors:\n" .. table.concat(issues, "\n"),
      vim.log.levels.ERROR
    )
  end

  if #warnings > 0 then
    vim.notify(
      "[monava] Configuration warnings:\n" .. table.concat(warnings, "\n"),
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
