-- lua/monava/core/init.lua
-- Core functionality for monorepo detection and management.

local M = {}
local cache = require("monava.utils.cache")
local fs = require("monava.utils.fs")
local utils = require("monava.utils")

-- Module state.
M.config = {}
M.detected_type = nil
M.root_path = nil
M.packages_cache = {}

-- Monorepo detection strategies.
local detectors = {
  javascript = {
    patterns = { "package.json", "nx.json", "lerna.json", "rush.json", "pnpm-workspace.yaml" },
    validate = function(root_path)
      local package_json = fs.read_file(root_path .. "/package.json")
      if package_json then
        local data, _ = utils.parse_json(package_json)
        local has_data = data ~= nil
        local is_workspace = has_data and (data.workspaces or data.private)
        if is_workspace then
          return true, "npm-workspaces"
        end
      end

      if fs.exists(root_path .. "/nx.json") then
        return true, "nx"
      end

      if fs.exists(root_path .. "/lerna.json") then
        return true, "lerna"
      end

      if fs.exists(root_path .. "/pnpm-workspace.yaml") then
        return true, "pnpm-workspaces"
      end

      return false
    end,
    get_packages = function(root_path, subtype)
      if subtype == "nx" then
        return M._get_nx_packages(root_path)
      elseif subtype == "lerna" then
        return M._get_lerna_packages(root_path)
      elseif subtype == "pnpm-workspaces" then
        return M._get_pnpm_packages(root_path)
      else
        return M._get_npm_packages(root_path)
      end
    end,
  },

  rust = {
    patterns = { "Cargo.toml" },
    validate = function(root_path)
      local cargo_toml = fs.read_file(root_path .. "/Cargo.toml")
      local has_cargo = cargo_toml ~= nil
      local is_workspace = has_cargo and cargo_toml:match("%[workspace%]")
      if is_workspace then
        return true, "cargo-workspace"
      end
      return false
    end,
    get_packages = function(root_path)
      return M._get_cargo_packages(root_path)
    end,
  },

  python = {
    patterns = { "pyproject.toml", "poetry.lock" },
    validate = function(root_path)
      local pyproject = fs.read_file(root_path .. "/pyproject.toml")
      if pyproject and pyproject:match("%[tool%.poetry%]") then
        return true, "poetry"
      end
      return false
    end,
    get_packages = function(root_path)
      return M._get_poetry_packages(root_path)
    end,
  },
}

-- Initialize core systems
function M.init(config)
  M.config = config or {}

  -- Initialize cache for this module.
  M.cache = cache.namespace("monava:core")

  -- Detect monorepo type and root.
  M._detect_monorepo()

  if config.debug then
    vim.notify(
      "[monava] Core systems initialized. Type: " .. (M.detected_type or "none"),
      vim.log.levels.INFO
    )
  end
end

-- Detect monorepo type and root directory.
function M._detect_monorepo()
  local cwd = vim.fn.getcwd()
  local cache_key = "detection:" .. cwd

  local cached_result = M._check_detection_cache(cache_key)
  if cached_result then
    return
  end

  local detection_result = M._walk_directory_tree(cwd)
  if detection_result then
    M._store_detection_result(detection_result, cache_key)
  else
    M._set_no_monorepo_detected(cwd)
  end
end

-- Check cache for previous detection results.
function M._check_detection_cache(cache_key)
  local cached = M.cache.get(cache_key)
  if cached then
    M.detected_type = cached.type
    M.root_path = cached.root
    M.subtype = cached.subtype
    return true
  end
  return false
end

-- Walk up directory tree looking for monorepo indicators.
function M._walk_directory_tree(start_path)
  local current_path = start_path
  local max_depth = M.config.detection and M.config.detection.max_depth or 3
  local depth = 0

  while current_path ~= "/" and depth < max_depth do
    local detection_result = M._check_path_for_monorepo(current_path)
    if detection_result then
      return detection_result
    end

    current_path = utils.path_dirname(current_path)
    depth = depth + 1
  end

  return nil
end

-- Check a specific path for monorepo indicators.
function M._check_path_for_monorepo(path)
  for lang, detector in pairs(detectors) do
    for _, pattern in ipairs(detector.patterns) do
      if fs.exists(path .. "/" .. pattern) then
        local is_valid, subtype = detector.validate(path)
        if is_valid then
          return {
            type = lang,
            root = path,
            subtype = subtype,
          }
        end
      end
    end
  end
  return nil
end

-- Store successful detection result.
function M._store_detection_result(result, cache_key)
  M.detected_type = result.type
  M.root_path = result.root
  M.subtype = result.subtype

  M.cache.set(cache_key, result, 300) -- 5 minute cache
end

-- Set state when no monorepo is detected.
function M._set_no_monorepo_detected(cwd)
  M.detected_type = nil
  M.root_path = cwd
end

-- Get all packages in the monorepo.
function M.get_packages()
  -- Validate core state
  if not M.detected_type then
    if M.config and M.config.debug then
      vim.notify("[monava] No monorepo detected in current directory", vim.log.levels.DEBUG)
    end
    return {}
  end

  if not M.root_path or M.root_path == "" then
    vim.notify("[monava] Invalid root path detected", vim.log.levels.ERROR)
    return {}
  end

  local cache_key = "packages:" .. M.root_path

  -- Check cache first
  local cached = M.cache and M.cache.get(cache_key)
  if cached then
    return cached
  end

  local detector = detectors[M.detected_type]
  if not detector or not detector.get_packages then
    vim.notify(
      "[monava] No package detector available for type: " .. M.detected_type,
      vim.log.levels.ERROR
    )
    return {}
  end

  local packages = detector.get_packages(M.root_path, M.subtype)

  -- Cache the result with file-based invalidation.
  local config_file = M._get_main_config_file()
  if config_file then
    M.cache.set_with_file_invalidation(cache_key, packages, config_file, 600) -- 10 minute cache
  else
    M.cache.set(cache_key, packages, 300) -- 5 minute cache
  end

  return packages
end

-- Get current package based on file location.
function M.get_current_package()
  -- Validate core state first
  if not M.detected_type then
    return nil
  end

  local current_file = vim.api.nvim_buf_get_name(0)
  if not current_file or current_file == "" then
    return nil
  end

  local packages = M.get_packages()
  if not packages or #packages == 0 then
    return nil
  end

  local current_dir = utils.path_dirname(current_file)

  -- Find the package that contains the current file.
  local best_match = nil
  local best_depth = -1

  for _, pkg in ipairs(packages) do
    if utils.starts_with(current_dir, pkg.path) then
      local depth = #vim.split(utils.path_relative(current_dir, pkg.path), "/")
      if depth > best_depth then
        best_match = pkg
        best_depth = depth
      end
    end
  end

  return best_match and best_match.name or nil
end

-- Get package information.
function M.get_package_info(package_name)
  local packages = M.get_packages()

  for _, pkg in ipairs(packages) do
    if pkg.name == package_name then
      return pkg
    end
  end

  return nil
end

-- Get package dependencies.
function M.get_dependencies(package_name)
  local package_info = M.get_package_info(package_name)
  if not package_info then
    return {}
  end

  if M.detected_type == "javascript" then
    return M._get_js_dependencies(package_info)
  elseif M.detected_type == "rust" then
    return M._get_rust_dependencies(package_info)
  end

  return {}
end

-- Get monorepo information.
function M.get_monorepo_info()
  return {
    type = M.detected_type,
    subtype = M.subtype,
    root = M.root_path,
    packages = M.get_packages(),
  }
end

-- Helper: Get main configuration file for cache invalidation.
function M._get_main_config_file()
  if not M.root_path then
    return nil
  end

  local config_files = {
    "package.json",
    "nx.json",
    "lerna.json",
    "Cargo.toml",
    "pyproject.toml",
  }

  for _, file in ipairs(config_files) do
    local path = M.root_path .. "/" .. file
    if fs.exists(path) then
      return path
    end
  end

  return nil
end

-- NPM/Yarn workspace package discovery.
function M._get_npm_packages(root_path)
  local package_json = fs.read_file(root_path .. "/package.json")
  if not package_json then
    return {}
  end

  local data, _ = utils.parse_json(package_json)
  if not data or not data.workspaces then
    return {}
  end

  local workspaces = data.workspaces
  local is_packages_format = type(workspaces) == "table" and workspaces.packages
  if is_packages_format then
    workspaces = workspaces.packages
  end

  local packages = {}
  for _, pattern in ipairs(workspaces) do
    local matches = fs.find_packages(root_path, { "package.json" }, {
      pattern = pattern,
      max_depth = 5,
    })

    for _, match in ipairs(matches) do
      local pkg_json = fs.read_file(match.path .. "/package.json")
      if pkg_json then
        local pkg_data = utils.parse_json(pkg_json)
        if pkg_data and pkg_data.name then
          table.insert(packages, {
            name = pkg_data.name,
            path = match.path,
            type = "npm-package",
            config_file = match.path .. "/package.json",
          })
        end
      end
    end
  end

  return packages
end

-- Nx workspace package discovery.
function M._get_nx_packages(root_path)
  local nx_json = fs.read_file(root_path .. "/nx.json")
  if not nx_json then
    return {}
  end

  -- Nx projects are typically in apps/ and libs/ directories.
  local packages = {}
  local project_dirs = { "apps", "libs", "packages" }

  for _, dir in ipairs(project_dirs) do
    local dir_path = root_path .. "/" .. dir
    if fs.is_dir(dir_path) then
      local entries = fs.scandir(dir_path, { type = "directory" })
      for _, entry in ipairs(entries) do
        local project_json = entry.path .. "/project.json"
        local package_json = entry.path .. "/package.json"

        if fs.exists(project_json) or fs.exists(package_json) then
          table.insert(packages, {
            name = entry.name,
            path = entry.path,
            type = "nx-project",
            config_file = fs.exists(project_json) and project_json or package_json,
          })
        end
      end
    end
  end

  return packages
end

-- Cargo workspace package discovery.
function M._get_cargo_packages(root_path)
  local cargo_toml = fs.read_file(root_path .. "/Cargo.toml")
  if not cargo_toml then
    return {}
  end

  local members = M._extract_workspace_members(cargo_toml)
  return M._discover_cargo_packages(root_path, members)
end

-- Extract workspace members from Cargo.toml content.
function M._extract_workspace_members(cargo_toml)
  local members = {}
  local in_workspace_section = false

  for line in cargo_toml:gmatch("[^\r\n]+") do
    local trimmed_line = line:match("^%s*(.-)%s*$")

    if M._is_workspace_section_start(trimmed_line) then
      in_workspace_section = true
    elseif M._is_new_section_start(trimmed_line) then
      in_workspace_section = false
    elseif in_workspace_section and M._is_members_line(trimmed_line) then
      M._parse_members_from_line(trimmed_line, members)
    end
  end

  return members
end

-- Check if line starts workspace section.
function M._is_workspace_section_start(line)
  return line:match("^%[workspace%]") ~= nil
end

-- Check if line starts a new TOML section.
function M._is_new_section_start(line)
  return line:match("^%[") ~= nil
end

-- Check if line defines workspace members.
function M._is_members_line(line)
  return line:match("^members%s*=") ~= nil
end

-- Parse member paths from members line.
function M._parse_members_from_line(line, members)
  local members_str = line:match("members%s*=%s*%[(.*)%]")
  if members_str then
    for member in members_str:gmatch('"([^"]*)"') do
      table.insert(members, member)
    end
  end
end

-- Discover packages in workspace member directories.
function M._discover_cargo_packages(root_path, members)
  local packages = {}

  for _, member in ipairs(members) do
    local package_info = M._create_cargo_package_info(root_path, member)
    if package_info then
      table.insert(packages, package_info)
    end
  end

  return packages
end

-- Create package info for a cargo member.
function M._create_cargo_package_info(root_path, member)
  local member_path = root_path .. "/" .. member
  local cargo_file = member_path .. "/Cargo.toml"

  if not fs.exists(cargo_file) then
    return nil
  end

  local member_toml = fs.read_file(cargo_file)
  if not member_toml then
    return nil
  end

  local name = member_toml:match('%[package%].-name%s*=%s*"([^"]*)"')
  if not name then
    return nil
  end

  return {
    name = name,
    path = member_path,
    type = "cargo-package",
    config_file = cargo_file,
  }
end

-- JavaScript dependency parsing.
function M._get_js_dependencies(package_info)
  local package_json = fs.read_file(package_info.config_file)
  if not package_json then
    return {}
  end

  local data = utils.parse_json(package_json)
  if not data then
    return {}
  end

  local deps = {}
  local dep_types = { "dependencies", "devDependencies", "peerDependencies" }

  for _, dep_type in ipairs(dep_types) do
    if data[dep_type] then
      for name, version in pairs(data[dep_type]) do
        table.insert(deps, {
          name = name,
          version = version,
          type = dep_type,
        })
      end
    end
  end

  return deps
end

-- Placeholder implementations for other package managers.
function M._get_lerna_packages(root_path)
  -- Fallback to npm packages discovery
  return M._get_npm_packages(root_path)
end

function M._get_pnpm_packages(root_path)
  -- Fallback to npm packages discovery
  return M._get_npm_packages(root_path)
end

function M._get_poetry_packages(root_path)
  -- Placeholder for Poetry monorepo support.
  return {}
end

function M._get_rust_dependencies(package_info)
  -- Placeholder for Rust dependency parsing.
  return {}
end

return M
