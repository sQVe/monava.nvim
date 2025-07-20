-- lua/monava/utils/cache.lua
-- Caching system for performance optimization

local M = {}

-- Cache storage with thread safety
local cache = {}
local cache_metadata = {}
local cache_locks = {} -- Per-key locks to prevent race conditions
local global_lock = false -- Global lock for cleanup operations

-- Default cache TTL (time to live) in seconds
local DEFAULT_TTL = 300 -- 5 minutes

-- Thread-safe cache operations with proper retry mechanism
local function with_lock(key, fn, max_retries)
  max_retries = max_retries or 3
  local retry_count = 0

  while retry_count < max_retries do
    -- Check if key is locked
    if not cache_locks[key] and not global_lock then
      cache_locks[key] = true

      local ok, result = pcall(fn)
      cache_locks[key] = nil

      if ok then
        return result
      else
        return nil, result
      end
    end

    -- Wait a small amount and retry
    retry_count = retry_count + 1
    vim.wait(1) -- Wait 1ms
  end

  return nil, "Cache operation timed out after " .. max_retries .. " retries"
end

-- Global lock for cleanup operations
local function with_global_lock(fn)
  if global_lock then
    return nil, "Global cache operation in progress"
  end

  global_lock = true
  -- Wait for all key-specific locks to clear
  local wait_count = 0
  while next(cache_locks) and wait_count < 100 do
    vim.wait(1)
    wait_count = wait_count + 1
  end

  local ok, result = pcall(fn)
  global_lock = false

  if ok then
    return result
  else
    return nil, result
  end
end

-- Initialize cache system
function M.init(config)
  M.config = config or { enabled = true, ttl = DEFAULT_TTL }

  -- Clear expired entries periodically
  if M.config.enabled then
    M._start_cleanup_timer()
  end
end

-- Start periodic cleanup timer with proper cleanup
function M._start_cleanup_timer()
  -- Stop existing timer to prevent multiple timers
  M._stop_cleanup_timer()

  M._cleanup_timer = vim.loop.new_timer()
  if M._cleanup_timer then
    M._cleanup_timer:start(60000, 60000, function() -- Every minute
      vim.schedule(function()
        with_global_lock(function()
          M.cleanup_expired()
        end)
      end)
    end)
  end
end

-- Stop cleanup timer properly
function M._stop_cleanup_timer()
  if M._cleanup_timer then
    if not M._cleanup_timer:is_closing() then
      M._cleanup_timer:stop()
      M._cleanup_timer:close()
    end
    M._cleanup_timer = nil
  end
end

-- Cleanup function to call on plugin unload
function M.cleanup()
  M._stop_cleanup_timer()
  cache = {}
  cache_metadata = {}
  cache_locks = {}
  global_lock = false
end

-- Generate cache key from multiple arguments
function M._generate_key(...)
  local parts = { ... }
  local key_parts = {}

  for _, part in ipairs(parts) do
    if type(part) == "table" then
      table.insert(key_parts, vim.json.encode(part))
    else
      table.insert(key_parts, tostring(part))
    end
  end

  return table.concat(key_parts, "|")
end

-- Set cache entry with thread safety
function M.set(key, value, ttl)
  if not M.config or not M.config.enabled then
    return false, "Cache disabled"
  end

  if type(key) ~= "string" then
    key = M._generate_key(key)
  end

  if not key then
    return false, "Invalid cache key"
  end

  ttl = ttl or M.config.ttl or DEFAULT_TTL
  if type(ttl) ~= "number" or ttl <= 0 then
    return false, "Invalid TTL value"
  end

  return with_lock(key, function()
    local expires_at = os.time() + ttl

    cache[key] = value
    cache_metadata[key] = {
      created_at = os.time(),
      expires_at = expires_at,
      access_count = 0,
    }

    return true
  end)
end

-- Get cache entry with thread safety
function M.get(key)
  if not M.config or not M.config.enabled then
    return nil
  end

  if type(key) ~= "string" then
    key = M._generate_key(key)
  end

  if not key then
    return nil
  end

  return with_lock(key, function()
    local metadata = cache_metadata[key]
    if not metadata then
      return nil
    end

    -- Check if expired
    if os.time() > metadata.expires_at then
      -- Clean up expired entry
      cache[key] = nil
      cache_metadata[key] = nil
      return nil
    end

    -- Update access count safely
    metadata.access_count = metadata.access_count + 1

    return cache[key]
  end)
end

-- Delete cache entry with thread safety
function M.delete(key)
  if type(key) ~= "string" then
    key = M._generate_key(key)
  end

  if not key then
    return false, "Invalid cache key"
  end

  return with_lock(key, function()
    cache[key] = nil
    cache_metadata[key] = nil
    return true
  end)
end

-- Check if key exists in cache
function M.has(key)
  if type(key) ~= "string" then
    key = M._generate_key(key)
  end

  return M.get(key) ~= nil
end

-- Clear all cache entries
function M.clear()
  cache = {}
  cache_metadata = {}
end

-- Clean up expired entries
function M.cleanup_expired()
  local current_time = os.time()
  local expired_keys = {}

  for key, metadata in pairs(cache_metadata) do
    if current_time > metadata.expires_at then
      table.insert(expired_keys, key)
    end
  end

  for _, key in ipairs(expired_keys) do
    M.delete(key)
  end

  return #expired_keys
end

-- Get cache statistics
function M.stats()
  local total_entries = 0
  local expired_entries = 0
  local total_access = 0
  local current_time = os.time()

  for key, metadata in pairs(cache_metadata) do
    total_entries = total_entries + 1
    total_access = total_access + metadata.access_count

    if current_time > metadata.expires_at then
      expired_entries = expired_entries + 1
    end
  end

  return {
    total_entries = total_entries,
    expired_entries = expired_entries,
    active_entries = total_entries - expired_entries,
    total_access = total_access,
    enabled = M.config and M.config.enabled or false,
  }
end

-- Memoize a function with caching
function M.memoize(func, ttl, key_generator)
  key_generator = key_generator or M._generate_key

  return function(...)
    local key = key_generator(...)
    local cached_result = M.get(key)

    if cached_result ~= nil then
      return cached_result
    end

    local result = func(...)
    M.set(key, result, ttl)

    return result
  end
end

-- Cache with file-based invalidation
function M.set_with_file_invalidation(key, value, file_path, ttl)
  if not M.config or not M.config.enabled then
    return
  end

  local fs = require("monava.utils.fs")
  local mtime = fs.get_mtime(file_path)

  if type(key) ~= "string" then
    key = M._generate_key(key)
  end

  ttl = ttl or M.config.ttl or DEFAULT_TTL
  local expires_at = os.time() + ttl

  cache[key] = value
  cache_metadata[key] = {
    created_at = os.time(),
    expires_at = expires_at,
    access_count = 0,
    file_path = file_path,
    file_mtime = mtime,
  }
end

-- Get with file-based invalidation check
function M.get_with_file_invalidation(key, file_path)
  if not M.config or not M.config.enabled then
    return nil
  end

  if type(key) ~= "string" then
    key = M._generate_key(key)
  end

  local metadata = cache_metadata[key]
  if not metadata then
    return nil
  end

  -- Check file modification time
  if metadata.file_path and file_path then
    local fs = require("monava.utils.fs")
    local current_mtime = fs.get_mtime(file_path)

    if current_mtime > metadata.file_mtime then
      M.delete(key)
      return nil
    end
  end

  return M.get(key)
end

-- Namespace-based cache operations
function M.namespace(ns)
  return {
    set = function(key, value, ttl)
      M.set(ns .. ":" .. key, value, ttl)
    end,
    get = function(key)
      return M.get(ns .. ":" .. key)
    end,
    delete = function(key)
      M.delete(ns .. ":" .. key)
    end,
    has = function(key)
      return M.has(ns .. ":" .. key)
    end,
    set_with_file_invalidation = function(key, value, file_path, ttl)
      M.set_with_file_invalidation(ns .. ":" .. key, value, file_path, ttl)
    end,
    get_with_file_invalidation = function(key, file_path)
      return M.get_with_file_invalidation(ns .. ":" .. key, file_path)
    end,
    clear = function()
      local keys_to_delete = {}
      for key in pairs(cache) do
        if key:sub(1, #ns + 1) == ns .. ":" then
          table.insert(keys_to_delete, key)
        end
      end
      for _, key in ipairs(keys_to_delete) do
        M.delete(key)
      end
    end,
  }
end

return M
