-- lua/monava/init.lua
-- Main entry point for the monava plugin.

local M = {}

local adapters = require("monava.adapters")
local config = require("monava.config")
local core = require("monava.core")
local errors = require("monava.utils.errors")
local utils = require("monava.utils")
local validation = require("monava.utils.validation")

-- Default configuration.
M._config = {}
M._initialized = false
M._packages_cache = nil
M._packages_cache_timestamp = 0
M._cache_lock = false

-- Setup function called by users with comprehensive error handling.
function M.setup(opts)
  -- Validate input parameters
  if not utils.validate_input(opts, "table", "setup options", true) then
    return false
  end

  opts = opts or {}

  local function safely_initialize_component(fn, component_name)
    local ok, err = pcall(fn)
    if not ok then
      vim.notify(
        "[monava] Failed to initialize " .. component_name .. ": " .. tostring(err),
        vim.log.levels.ERROR
      )
      return false
    end
    return true
  end

  -- Validate and merge user config with defaults.
  local ok, merged_config = pcall(config.merge_config, opts)
  if not ok then
    vim.notify("[monava] Configuration error: " .. tostring(merged_config), vim.log.levels.ERROR)
    return false
  end

  -- Validate merged configuration.
  if not config.validate_config(merged_config) then
    vim.notify("[monava] Invalid configuration provided", vim.log.levels.ERROR)
    return false
  end

  M._config = merged_config

  -- Initialize core systems with error handling.
  if not safely_initialize_component(function()
    core.init(M._config)
  end, "core systems") then
    return false
  end

  -- Detect and initialize available pickers with error handling.
  if
    not safely_initialize_component(function()
      adapters.init(M._config)
    end, "picker adapters")
  then
    return false
  end

  -- Set up keymaps with error handling.
  if M._config.keymaps then
    safely_initialize_component(function()
      config.setup_keymaps(M._config)
    end, "keymaps")
  end

  M._initialized = true

  if M._config.debug then
    vim.notify("[monava] Plugin initialized successfully", vim.log.levels.INFO)
  end

  return true
end

-- Ensure plugin is initialized before operations.
local function ensure_initialized()
  if not M._initialized then
    M.setup()
  end
end

-- Get packages with module-level caching (5-second cache) and race condition protection
local function get_cached_packages()
  local current_time = vim.loop.hrtime() / 1000000
  local cache_ttl = 5000 -- 5 seconds

  -- Check if cache is valid (without lock for performance)
  if M._packages_cache and (current_time - M._packages_cache_timestamp) < cache_ttl then
    return M._packages_cache
  end

  -- Prevent concurrent cache refreshes
  if M._cache_lock then
    -- Wait briefly for the other refresh to complete, then return current cache
    vim.wait(100, function()
      return not M._cache_lock
    end, 10)
    return M._packages_cache or {}
  end

  -- Acquire lock
  M._cache_lock = true

  -- Double-check cache validity after acquiring lock
  if M._packages_cache and (current_time - M._packages_cache_timestamp) < cache_ttl then
    M._cache_lock = false
    return M._packages_cache
  end

  -- Refresh cache with error handling
  local packages
  local ok, result = pcall(core.get_packages)
  if ok then
    packages = result
  else
    errors.notify_error(
      errors.CODES.CACHE_ERROR,
      "Failed to refresh package cache: " .. tostring(result)
    )
    packages = M._packages_cache or {} -- Return stale cache on error
  end

  if packages and not vim.tbl_isempty(packages) then
    M._packages_cache = packages
    M._packages_cache_timestamp = current_time
  else
    -- Don't cache empty results, always re-fetch
    M._packages_cache = nil
    M._packages_cache_timestamp = 0
  end

  -- Release lock
  M._cache_lock = false

  return packages or {}
end

-- Invalidate the module-level package cache with lock protection
function M._invalidate_package_cache()
  -- Wait for any ongoing cache operations to complete
  if M._cache_lock then
    vim.wait(100, function()
      return not M._cache_lock
    end, 10)
  end

  M._packages_cache = nil
  M._packages_cache_timestamp = 0
end

-- Show available packages in the monorepo.
function M.show_package_picker()
  ensure_initialized()

  local packages = get_cached_packages()
  if not packages or vim.tbl_isempty(packages) then
    vim.notify("[monava] No packages found in current directory", vim.log.levels.WARN)
    return
  end

  -- Validate packages structure
  if not utils.validate_package_structure(packages, "show_package_picker") then
    return
  end

  adapters.show_packages(packages)
end

-- Switch to a different package/workspace.
function M.switch()
  ensure_initialized()

  local packages = get_cached_packages()
  if not packages or vim.tbl_isempty(packages) then
    vim.notify("[monava] No packages found in current directory", vim.log.levels.WARN)
    return
  end

  -- Validate packages structure
  if not utils.validate_package_structure(packages, "switch") then
    return
  end

  adapters.switch_package(packages)
end

-- Find files within a specific package.
function M.files(package_name)
  ensure_initialized()

  -- Validate package_name if provided
  if package_name then
    local valid, err = validation.validate_package_name(package_name)
    if not valid then
      errors.notify_error(errors.CODES.INVALID_INPUT, err)
      return
    end
  end

  if not package_name then
    -- If no package specified, use current context or prompt.
    package_name = core.get_current_package()
    if not package_name then
      vim.notify(
        "[monava] No package specified and could not detect current package",
        vim.log.levels.WARN
      )
      return
    end
  end

  local package_info = core.get_package_info(package_name)
  if not package_info then
    vim.notify("[monava] Package not found: " .. package_name, vim.log.levels.ERROR)
    return
  end

  -- Validate package_info structure
  if type(package_info) ~= "table" or not package_info.name or not package_info.path then
    vim.notify("[monava] Invalid package info for: " .. package_name, vim.log.levels.ERROR)
    return
  end

  adapters.find_files(package_info)
end

-- Show package dependencies.
function M.dependencies(package_name)
  ensure_initialized()

  -- Validate package_name if provided
  if package_name then
    local valid, err = validation.validate_package_name(package_name)
    if not valid then
      errors.notify_error(errors.CODES.INVALID_INPUT, err)
      return
    end
  end

  if not package_name then
    package_name = core.get_current_package()
    if not package_name then
      vim.notify(
        "[monava] No package specified and could not detect current package",
        vim.log.levels.WARN
      )
      return
    end
  end

  local deps = core.get_dependencies(package_name)
  if not deps or vim.tbl_isempty(deps) then
    vim.notify("[monava] No dependencies found for package: " .. package_name, vim.log.levels.INFO)
    return
  end

  -- Validate dependencies structure
  if not utils.validate_package_structure(deps, "dependencies") then
    return
  end

  adapters.show_dependencies(package_name, deps)
end

-- Show monorepo information.
function M.info()
  ensure_initialized()

  local info = core.get_monorepo_info()

  local lines = {
    "Monava - Monorepo Navigation",
    "========================",
    "",
    "Monorepo Type: " .. (info.type or "Unknown"),
    "Root Directory: " .. (info.root or vim.fn.getcwd()),
    "Packages Found: " .. #info.packages,
    "Available Pickers: " .. table.concat(adapters.get_available_pickers(), ", "),
    "",
    "Packages:",
  }

  for _, pkg in ipairs(info.packages) do
    table.insert(lines, "  - " .. pkg.name .. " (" .. pkg.path .. ")")
  end

  -- Create a new buffer to display the info.
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "monava-info")

  -- Open in a new window.
  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_height(0, math.min(#lines + 2, 20))
end

-- Expose configuration for debugging.
function M.get_config()
  return M._config
end

-- Health check function.
function M.health()
  local health_ok, health = pcall(require, "vim.health")
  if not health_ok then
    health = require("health")
  end

  health.report_start("monava.nvim")

  -- Check Neovim version.
  if vim.fn.has("nvim-0.9.0") == 1 then
    health.report_ok("Neovim version >= 0.9.0")
  else
    health.report_error("Neovim version < 0.9.0")
  end

  -- Check for available pickers.
  local available_pickers = adapters.get_available_pickers()
  if #available_pickers > 0 then
    health.report_ok("Available pickers: " .. table.concat(available_pickers, ", "))
  else
    health.report_warn("No supported pickers found (telescope, fzf-lua, snacks)")
  end

  -- Check for monorepo in current directory.
  ensure_initialized()
  local info = core.get_monorepo_info()
  if info.type then
    health.report_ok("Monorepo detected: " .. info.type)
    health.report_info("Packages found: " .. #info.packages)
  else
    health.report_info("No monorepo detected in current directory")
  end
end

return M
