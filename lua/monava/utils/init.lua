-- lua/monava/utils/init.lua
-- Common utility functions.

local M = {}

-- Import sub-modules.
M.fs = require("monava.utils.fs")
M.cache = require("monava.utils.cache")

function M.starts_with(str, prefix)
  return str:sub(1, #prefix) == prefix
end

function M.ends_with(str, suffix)
  return str:sub(-#suffix) == suffix
end

function M.trim(str)
  return str:match("^%s*(.-)%s*$")
end

function M.table_contains(table, value)
  for _, v in ipairs(table) do
    if v == value then
      return true
    end
  end
  return false
end

function M.table_merge(target, source)
  for k, v in pairs(source) do
    target[k] = v
  end
  return target
end

function M.table_keys(table)
  local keys = {}
  for k, _ in pairs(table) do
    table.insert(keys, k)
  end
  return keys
end

function M.path_join(...)
  local parts = { ... }
  local path = table.concat(parts, "/")
  -- Ensure consistent path format for cross-platform compatibility.
  path = path:gsub("//+", "/")
  return path
end

function M.path_relative(path, base)
  base = base or vim.fn.getcwd()
  -- Path resolution requires absolute paths for reliable comparison.
  if not M.starts_with(path, "/") then
    path = M.path_join(base, path)
  end
  if not M.starts_with(base, "/") then
    base = vim.fn.fnamemodify(base, ":p")
  end

  -- Normalize for consistent path comparison.
  base = base:gsub("/$", "")
  path = path:gsub("/$", "")

  if M.starts_with(path, base .. "/") then
    return path:sub(#base + 2)
  elseif path == base then
    return "."
  else
    return path
  end
end

function M.path_dirname(path)
  return vim.fn.fnamemodify(path, ":h")
end

function M.path_basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

-- JSON utilities with size limits and validation.
function M.parse_json(content, max_size)
  if type(content) ~= "string" then
    return nil, "Content must be a string"
  end

  max_size = max_size or 1024 * 1024 -- 1MB default limit
  if #content > max_size then
    return nil, "JSON content too large: " .. #content .. " bytes (max: " .. max_size .. ")"
  end

  -- Prevent malformed JSON from causing parser crashes.
  if not content:match("^%s*[{%[]") then
    return nil, "Invalid JSON: must start with { or ["
  end

  local ok, result = pcall(vim.json.decode, content)
  if ok then
    return result
  else
    return nil, "JSON parse error: " .. tostring(result)
  end
end

function M.encode_json(data, max_depth)
  if data == nil then
    return nil, "Cannot encode nil value"
  end

  max_depth = max_depth or 50

  -- Prevent stack overflow from circular references.
  local function check_depth(obj, depth)
    if depth > max_depth then
      return false
    end
    if type(obj) == "table" then
      for _, v in pairs(obj) do
        if not check_depth(v, depth + 1) then
          return false
        end
      end
    end
    return true
  end

  if not check_depth(data, 1) then
    return nil, "Data structure too deep (max depth: " .. max_depth .. ")"
  end

  local ok, result = pcall(vim.json.encode, data)
  if ok then
    return result
  else
    return nil, "JSON encode error: " .. tostring(result)
  end
end

-- Improved async utilities with better resource management
function M.run_async(cmd, callback, opts)
  opts = opts or {}
  local timeout = opts.timeout or 30000 -- 30 second default
  local max_output_size = opts.max_output_size or 1024 * 1024 -- 1MB default

  -- Enhanced validation
  if not M.validate_input(cmd, "table", "command") or #cmd == 0 then
    if callback then
      callback(-1, "", "Invalid command: must be non-empty table")
    end
    return nil
  end

  if not M.validate_input(callback, "function", "callback") then
    error("Callback must be a function")
  end

  -- Sanitize and validate arguments
  for i, arg in ipairs(cmd) do
    if type(arg) ~= "string" and type(arg) ~= "number" then
      if callback then
        callback(-1, "", "Invalid argument type: " .. type(arg))
      end
      return nil
    end
    -- Convert numbers to strings
    if type(arg) == "number" then
      cmd[i] = tostring(arg)
    end
  end

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local handle
  local timer
  local finished = false

  local stdout_data = {}
  local stderr_data = {}
  local total_output_size = 0

  -- Enhanced cleanup with error handling
  local function cleanup()
    if finished then
      return
    end
    finished = true

    -- Stop timer safely
    if timer and not timer:is_closing() then
      pcall(function()
        timer:stop()
      end)
      pcall(function()
        timer:close()
      end)
    end

    -- Close pipes safely
    if stdout and not stdout:is_closing() then
      pcall(function()
        stdout:read_stop()
      end)
      pcall(function()
        stdout:close()
      end)
    end
    if stderr and not stderr:is_closing() then
      pcall(function()
        stderr:read_stop()
      end)
      pcall(function()
        stderr:close()
      end)
    end

    -- Terminate process safely
    if handle and not handle:is_closing() then
      pcall(function()
        handle:kill("sigterm")
      end)
      -- Give it a moment, then force kill if needed
      vim.defer_fn(function()
        if handle and not handle:is_closing() then
          pcall(function()
            handle:kill("sigkill")
          end)
          pcall(function()
            handle:close()
          end)
        end
      end, 100)
    end
  end

  -- Set up timeout with better error handling
  timer = vim.loop.new_timer()
  if not timer then
    if callback then
      callback(-1, "", "Failed to create timer")
    end
    return nil
  end

  timer:start(timeout, 0, function()
    cleanup()
    vim.schedule(function()
      callback(-1, "", "Command timed out after " .. timeout .. "ms")
    end)
  end)

  -- Start the process with better error handling
  handle = vim.loop.spawn(cmd[1], {
    args = vim.list_slice(cmd, 2),
    stdio = { nil, stdout, stderr },
  }, function(code, signal)
    cleanup()
    vim.schedule(function()
      callback(code or -1, table.concat(stdout_data), table.concat(stderr_data))
    end)
  end)

  if not handle then
    cleanup()
    if callback then
      callback(-1, "", "Failed to spawn command: " .. cmd[1])
    end
    return nil
  end

  -- Read from pipes with size limits
  stdout:read_start(function(err, data)
    if err or finished then
      return
    end
    if data then
      total_output_size = total_output_size + #data
      if total_output_size > max_output_size then
        cleanup()
        vim.schedule(function()
          callback(-1, "", "Output size exceeded limit: " .. max_output_size .. " bytes")
        end)
        return
      end
      table.insert(stdout_data, data)
    end
  end)

  stderr:read_start(function(err, data)
    if err or finished then
      return
    end
    if data then
      total_output_size = total_output_size + #data
      if total_output_size > max_output_size then
        cleanup()
        vim.schedule(function()
          callback(-1, "", "Output size exceeded limit: " .. max_output_size .. " bytes")
        end)
        return
      end
      table.insert(stderr_data, data)
    end
  end)

  return {
    handle = handle,
    cancel = cleanup,
    is_finished = function()
      return finished
    end,
  }
end

-- Debounce function for performance.
function M.debounce(func, delay)
  local timer = nil
  return function(...)
    local args = { ... }
    if timer then
      timer:stop()
      timer:close()
    end
    timer = vim.loop.new_timer()
    timer:start(delay, 0, function()
      timer:close()
      timer = nil
      vim.schedule(function()
        func(unpack(args))
      end)
    end)
  end
end

-- YAML parsing utility for PNPM workspace files.
function M.parse_pnpm_workspace_yaml(content)
  if type(content) ~= "string" then
    return nil, "Content must be a string"
  end

  -- Basic validation.
  if #content == 0 then
    return nil, "Empty YAML content"
  end

  -- Simple YAML parser specifically for pnpm-workspace.yaml format.
  -- Expected format:
  -- packages:
  --   - "packages/*"
  --   - "apps/*"
  local packages = {}
  local in_packages = false

  for line in content:gmatch("[^\r\n]+") do
    local trimmed = M.trim(line)

    -- Skip comments and empty lines.
    if trimmed == "" or trimmed:match("^#") then
      goto continue
    end

    -- Check for packages section.
    if trimmed:match("^packages%s*:") then
      in_packages = true
      goto continue
    end

    -- If we're in packages section, parse array items.
    if in_packages then
      -- Check for array item (starts with -).
      local pattern = trimmed:match("^%-%s*[\"']?([^\"']+)[\"']?%s*$")
      if pattern then
        table.insert(packages, pattern)
      else
        -- If we hit a non-array item and we have packages, we're done.
        if #packages > 0 and not trimmed:match("^%s*$") then
          break
        end
      end
    end

    ::continue::
  end

  if #packages == 0 then
    return nil, "No packages found in YAML"
  end

  return { packages = packages }
end

-- Glob pattern matching utility for workspace patterns.
function M.glob_match(pattern, path)
  -- Convert glob pattern to Lua pattern.
  local lua_pattern = pattern

  -- Escape special Lua pattern characters except our glob characters.
  lua_pattern = lua_pattern:gsub("([%^%$%(%)%%%.%[%]%+%-])", "%%%1")

  -- Convert glob patterns to Lua patterns
  lua_pattern = lua_pattern:gsub("%*%*", "DOUBLESTAR") -- Temporarily replace **
  lua_pattern = lua_pattern:gsub("%*", "SINGLESTAR") -- Temporarily replace *
  lua_pattern = lua_pattern:gsub("%?", "QUESTION") -- Temporarily replace ?

  -- Convert our placeholders to Lua patterns.
  lua_pattern = lua_pattern:gsub("DOUBLESTAR", ".*") -- ** -> .*
  lua_pattern = lua_pattern:gsub("SINGLESTAR", "[^/]*") -- * -> [^/]*
  lua_pattern = lua_pattern:gsub("QUESTION", ".") -- ? -> .

  -- Anchor pattern.
  lua_pattern = "^" .. lua_pattern .. "$"

  return path:match(lua_pattern) ~= nil
end

-- Expand glob patterns to find matching directories with simple limits.
function M.expand_glob_pattern(root_path, pattern, options)
  local matches = {}
  local max_matches = (options and options.max_matches) or 1000 -- Simple limit
  local max_depth = (options and options.max_depth) or 10 -- Simple depth limit

  -- Handle exclusion patterns (patterns starting with !).
  if pattern:match("^!") then
    return matches, true -- Return empty matches and indicate it's an exclusion
  end

  -- Parse pattern into components.
  local parts = {}
  for part in pattern:gmatch("[^/]+") do
    table.insert(parts, part)
  end

  if #parts == 0 then
    return matches, false
  end

  -- Simple recursive scanning
  local function scan_recursive(current_path, current_relative, part_index, depth)
    if part_index > #parts or depth > max_depth or #matches >= max_matches then
      return
    end

    local part = parts[part_index]
    local is_last_part = part_index == #parts

    local handle = vim.loop.fs_scandir(current_path)
    if not handle then
      return
    end

    while true do
      local name, type = vim.loop.fs_scandir_next(handle)
      if not name or #matches >= max_matches then
        break
      end

      if type == "directory" then
        local matches_part

        if part == "*" or part == "**" then
          matches_part = true
        else
          matches_part = M.glob_match(part, name)
        end

        if matches_part then
          local full_path = current_path .. "/" .. name
          local rel_path = current_relative == "" and name or current_relative .. "/" .. name

          if is_last_part then
            -- Check for package.json
            local package_json = full_path .. "/package.json"
            local stat = vim.loop.fs_stat(package_json)
            if stat and stat.type == "file" then
              table.insert(matches, {
                name = name,
                path = full_path,
                relative_path = rel_path,
              })
            end
          else
            -- Continue to next part
            if part == "**" then
              -- For **, try both staying at current part and moving to next
              scan_recursive(full_path, rel_path, part_index, depth + 1)
              scan_recursive(full_path, rel_path, part_index + 1, depth + 1)
            else
              scan_recursive(full_path, rel_path, part_index + 1, depth + 1)
            end
          end
        end
      end
    end
  end

  scan_recursive(root_path, "", 1, 0)
  return matches, false
end

-- Error handling utilities
function M.safe_call(func, ...)
  local ok, result = pcall(func, ...)
  if ok then
    return result
  else
    vim.notify("[monava] Error: " .. tostring(result), vim.log.levels.ERROR)
    return nil
  end
end

-- Standardized error handling for operations
function M.handle_error(operation_name, error_msg, level)
  level = level or vim.log.levels.ERROR
  local formatted_msg = string.format("[monava] %s failed: %s", operation_name, tostring(error_msg))
  vim.notify(formatted_msg, level)
end

-- Validation helper with consistent error reporting
function M.validate_input(value, expected_type, name, allow_nil)
  if allow_nil and value == nil then
    return true
  end

  if value == nil then
    M.handle_error("Input validation", name .. " cannot be nil")
    return false
  end

  if type(value) ~= expected_type then
    M.handle_error(
      "Input validation",
      string.format("%s must be %s, got %s", name, expected_type, type(value))
    )
    return false
  end

  if expected_type == "string" and value == "" then
    M.handle_error("Input validation", name .. " cannot be empty string")
    return false
  end

  return true
end

-- Package structure validation
function M.validate_package_structure(packages, context)
  context = context or "package validation"
  if not packages or type(packages) ~= "table" then
    M.handle_error(context, "packages must be a table")
    return false
  end

  for i, pkg in ipairs(packages) do
    if type(pkg) ~= "table" then
      M.handle_error(context, "package at index " .. i .. " must be a table")
      return false
    end
    if not pkg.name or not pkg.path then
      M.handle_error(context, "package at index " .. i .. " missing name or path")
      return false
    end
    if type(pkg.name) ~= "string" or type(pkg.path) ~= "string" then
      M.handle_error(context, "package name and path must be strings")
      return false
    end
  end

  return true
end

-- Logging utilities
function M.log(level, message, ...)
  if type(message) == "string" and select("#", ...) > 0 then
    message = string.format(message, ...)
  end
  vim.notify("[monava] " .. tostring(message), level)
end

function M.debug(message, ...)
  if vim.g.monava_debug then
    M.log(vim.log.levels.DEBUG, message, ...)
  end
end

function M.info(message, ...)
  M.log(vim.log.levels.INFO, message, ...)
end

function M.warn(message, ...)
  M.log(vim.log.levels.WARN, message, ...)
end

function M.error(message, ...)
  M.log(vim.log.levels.ERROR, message, ...)
end

return M
