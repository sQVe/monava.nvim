-- lua/monava/utils/init.lua
-- Common utility functions

local M = {}

-- Import sub-modules
M.fs = require("monava.utils.fs")
M.cache = require("monava.utils.cache")

-- String utilities
function M.starts_with(str, prefix)
  return str:sub(1, #prefix) == prefix
end

function M.ends_with(str, suffix)
  return str:sub(-#suffix) == suffix
end

function M.trim(str)
  return str:match("^%s*(.-)%s*$")
end

-- Table utilities
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

-- Path utilities
function M.path_join(...)
  local parts = { ... }
  local path = table.concat(parts, "/")
  -- Normalize path separators and remove duplicate slashes
  path = path:gsub("//+", "/")
  return path
end

function M.path_relative(path, base)
  base = base or vim.fn.getcwd()
  -- Ensure both paths are absolute
  if not M.starts_with(path, "/") then
    path = M.path_join(base, path)
  end
  if not M.starts_with(base, "/") then
    base = vim.fn.fnamemodify(base, ":p")
  end

  -- Remove trailing slashes
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

-- JSON utilities with size limits and validation
function M.parse_json(content, max_size)
  if type(content) ~= "string" then
    return nil, "Content must be a string"
  end

  max_size = max_size or 1024 * 1024 -- 1MB default limit
  if #content > max_size then
    return nil, "JSON content too large: " .. #content .. " bytes (max: " .. max_size .. ")"
  end

  -- Basic validation to prevent malformed JSON from causing issues
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

  -- Simple depth check to prevent infinite recursion
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

-- Async utilities with proper cleanup and validation
function M.run_async(cmd, callback, opts)
  opts = opts or {}
  local timeout = opts.timeout or 30000 -- 30 second default timeout

  -- Validate inputs
  if type(cmd) ~= "table" or #cmd == 0 then
    if callback then
      callback(-1, "", "Invalid command: must be non-empty table")
    end
    return nil
  end

  if type(callback) ~= "function" then
    error("Callback must be a function")
  end

  -- Sanitize command arguments
  local clean_cmd = {}
  for i, arg in ipairs(cmd) do
    if type(arg) == "string" then
      -- Basic sanitization - remove dangerous characters
      local clean_arg = arg:gsub("[;&|`$()]", "")
      table.insert(clean_cmd, clean_arg)
    end
  end

  if #clean_cmd == 0 then
    if callback then
      callback(-1, "", "No valid command arguments after sanitization")
    end
    return nil
  end

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local handle
  local timer
  local finished = false

  local stdout_data = {}
  local stderr_data = {}

  local function cleanup()
    if finished then
      return
    end
    finished = true

    if timer then
      timer:stop()
      timer:close()
    end

    if stdout and not stdout:is_closing() then
      stdout:close()
    end
    if stderr and not stderr:is_closing() then
      stderr:close()
    end
    if handle and not handle:is_closing() then
      handle:kill("sigterm")
      handle:close()
    end
  end

  -- Set up timeout
  timer = vim.loop.new_timer()
  timer:start(timeout, 0, function()
    cleanup()
    vim.schedule(function()
      callback(-1, "", "Command timed out after " .. timeout .. "ms")
    end)
  end)

  handle = vim.loop.spawn(clean_cmd[1], {
    args = vim.list_slice(clean_cmd, 2),
    stdio = { nil, stdout, stderr },
  }, function(code, signal)
    cleanup()

    vim.schedule(function()
      callback(code, table.concat(stdout_data), table.concat(stderr_data))
    end)
  end)

  if not handle then
    cleanup()
    if callback then
      callback(-1, "", "Failed to spawn command")
    end
    return nil
  end

  stdout:read_start(function(err, data)
    if err then
      -- Handle read errors gracefully
      return
    end
    if data then
      table.insert(stdout_data, data)
    end
  end)

  stderr:read_start(function(err, data)
    if err then
      -- Handle read errors gracefully
      return
    end
    if data then
      table.insert(stderr_data, data)
    end
  end)

  return {
    handle = handle,
    cancel = cleanup,
  }
end

-- Debounce function for performance
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
