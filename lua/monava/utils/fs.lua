-- lua/monava/utils/fs.lua
-- File system utility functions

local M = {}

-- Basic path validation to prevent obvious mistakes
local function validate_path(path)
  if not path or type(path) ~= "string" or path == "" then
    return nil, "Invalid path: must be a non-empty string"
  end

  -- Convert to absolute path
  local abs_path = vim.fn.fnamemodify(path, ":p")
  if not abs_path or abs_path == "" then
    return nil, "Invalid path: cannot resolve to absolute path"
  end

  -- Remove trailing slashes for consistency
  abs_path = abs_path:gsub("/$", "")

  -- Basic workspace boundary check - ensure we're in current working directory tree
  local cwd = vim.fn.getcwd():gsub("/$", "")
  if not (abs_path == cwd or abs_path:sub(1, #cwd + 1) == cwd .. "/") then
    -- Allow temp directories for testing
    local temp_paths = { "/tmp", vim.fn.stdpath("cache") }
    local in_temp = false
    for _, temp in ipairs(temp_paths) do
      if abs_path:sub(1, #temp + 1) == temp .. "/" or abs_path == temp then
        in_temp = true
        break
      end
    end
    if not in_temp then
      return nil, "Path outside workspace: " .. abs_path
    end
  end

  return abs_path
end

-- Check if a file or directory exists
function M.exists(path)
  local clean_path, _ = validate_path(path)
  if not clean_path then
    return false
  end

  local ok, stat = pcall(vim.loop.fs_stat, clean_path)
  return ok and stat ~= nil
end

-- Check if path is a file
function M.is_file(path)
  local clean_path, _ = validate_path(path)
  if not clean_path then
    return false
  end

  local ok, stat = pcall(vim.loop.fs_stat, clean_path)
  return ok and stat and stat.type == "file"
end

-- Check if path is a directory
function M.is_dir(path)
  local clean_path, _ = validate_path(path)
  if not clean_path then
    return false
  end

  local ok, stat = pcall(vim.loop.fs_stat, clean_path)
  return ok and stat and stat.type == "directory"
end

-- Read file contents with size limits for security
function M.read_file(path, max_size)
  local clean_path, err = validate_path(path)
  if not clean_path then
    return nil, err
  end

  max_size = max_size or 10 * 1024 * 1024 -- 10MB default limit

  local ok, fd = pcall(vim.loop.fs_open, clean_path, "r", 438)
  if not ok or not fd then
    return nil, "Failed to open file: " .. clean_path
  end

  local ok_stat, stat = pcall(vim.loop.fs_fstat, fd)
  if not ok_stat or not stat then
    vim.loop.fs_close(fd)
    return nil, "Failed to get file stats"
  end

  if stat.size > max_size then
    vim.loop.fs_close(fd)
    return nil, "File too large: " .. stat.size .. " bytes (max: " .. max_size .. ")"
  end

  local ok_read, data = pcall(vim.loop.fs_read, fd, stat.size, 0)
  vim.loop.fs_close(fd)

  if not ok_read then
    return nil, "Failed to read file contents"
  end

  return data
end

-- Write file contents with validation
function M.write_file(path, content)
  local clean_path, err = validate_path(path)
  if not clean_path then
    return false, err
  end

  if type(content) ~= "string" then
    return false, "Content must be a string"
  end

  local ok, fd = pcall(vim.loop.fs_open, clean_path, "w", 438)
  if not ok or not fd then
    return false, "Failed to open file for writing: " .. clean_path
  end

  local ok_write, err_write = pcall(vim.loop.fs_write, fd, content, 0)
  vim.loop.fs_close(fd)

  if not ok_write then
    return false, "Failed to write file contents: " .. (err_write or "unknown error")
  end

  return true
end

-- Get directory contents
function M.scandir(path, opts)
  opts = opts or {}
  local entries = {}

  local handle = vim.loop.fs_scandir(path)
  if not handle then
    return entries
  end

  while true do
    local name, type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    -- Skip hidden files unless requested
    if not opts.include_hidden and name:sub(1, 1) == "." then
      goto continue
    end

    -- Filter by type if specified
    if opts.type and type ~= opts.type then
      goto continue
    end

    table.insert(entries, {
      name = name,
      type = type,
      path = path .. "/" .. name,
    })

    ::continue::
  end

  return entries
end

-- Find files matching patterns with bounds checking and limits
function M.find_files(root, patterns, opts)
  opts = opts or {}
  local max_depth = math.min(opts.max_depth or 10, 20) -- Cap at 20 levels
  local max_results = opts.max_results or 10000 -- Prevent memory issues
  local exclude_patterns = opts.exclude_patterns or {}
  local results = {}
  local file_count = 0

  -- Validate inputs
  local clean_root, err = validate_path(root)
  if not clean_root then
    return {}, err
  end

  if not patterns or #patterns == 0 then
    return {}, "No patterns provided"
  end

  local function should_exclude(path)
    for _, pattern in ipairs(exclude_patterns) do
      local ok, match = pcall(string.match, path, pattern)
      if ok and match then
        return true
      end
    end
    return false
  end

  local function search_recursive(dir, depth)
    if depth > max_depth or file_count >= max_results then
      return
    end

    local entries = M.scandir(dir, { include_hidden = opts.include_hidden })

    for _, entry in ipairs(entries) do
      if file_count >= max_results then
        break
      end

      if should_exclude(entry.path) then
        goto continue
      end

      if entry.type == "file" then
        for _, pattern in ipairs(patterns) do
          local ok, match = pcall(string.match, entry.name, pattern)
          local pattern_matches = (ok and match) or entry.name == pattern
          if pattern_matches then
            table.insert(results, entry.path)
            file_count = file_count + 1
            break
          end
        end
      elseif entry.type == "directory" then
        search_recursive(entry.path, depth + 1)
      end

      ::continue::
    end
  end

  search_recursive(clean_root, 0)
  return results
end

-- Find directories containing specific files
function M.find_packages(root, indicator_files, opts)
  opts = opts or {}
  local max_depth = opts.max_depth or 5
  local exclude_patterns = opts.exclude_patterns or { "node_modules", ".git", "target", "dist" }
  local packages = {}

  local function should_exclude(path)
    for _, pattern in ipairs(exclude_patterns) do
      if path:match(pattern) then
        return true
      end
    end
    return false
  end

  local function search_recursive(dir, depth)
    if depth > max_depth then
      return
    end

    -- Check if current directory contains any indicator files
    local found_indicators = {}
    for _, file in ipairs(indicator_files) do
      local file_path = dir .. "/" .. file
      if M.exists(file_path) then
        table.insert(found_indicators, file)
      end
    end

    if #found_indicators > 0 then
      table.insert(packages, {
        path = dir,
        indicators = found_indicators,
        name = vim.fn.fnamemodify(dir, ":t"),
      })
    end

    -- Continue searching subdirectories
    local entries = M.scandir(dir, { type = "directory" })
    for _, entry in ipairs(entries) do
      if not should_exclude(entry.path) then
        search_recursive(entry.path, depth + 1)
      end
    end
  end

  search_recursive(root, 0)
  return packages
end

-- Get file modification time
function M.get_mtime(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.mtime.sec or 0
end

-- Create directory recursively
function M.mkdir(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    table.insert(parts, part)
  end

  local current = ""
  for _, part in ipairs(parts) do
    current = current .. "/" .. part
    if not M.exists(current) then
      vim.loop.fs_mkdir(current, 511) -- 0777 in octal
    end
  end
end

-- Get relative path from base to target
function M.relative_path(target, base)
  base = base or vim.fn.getcwd()

  -- Normalize paths
  target = vim.fn.resolve(target)
  base = vim.fn.resolve(base)

  -- Use vim's built-in function if available
  if vim.fn.has("nvim-0.8.0") == 1 then
    return vim.fn.fnamemodify(target, ":~:.")
  else
    -- Fallback implementation
    if target:sub(1, #base) == base then
      local relative = target:sub(#base + 1)
      if relative:sub(1, 1) == "/" then
        relative = relative:sub(2)
      end
      return relative ~= "" and relative or "."
    else
      return target
    end
  end
end

-- Find the nearest file walking up the directory tree
function M.find_up(filename, start_path)
  start_path = start_path or vim.fn.getcwd()
  local current = start_path

  while current ~= "/" do
    local file_path = current .. "/" .. filename
    if M.exists(file_path) then
      return file_path
    end
    current = vim.fn.fnamemodify(current, ":h")
  end

  return nil
end

-- Get file size in bytes
function M.get_size(path)
  local stat = vim.loop.fs_stat(path)
  return stat and stat.size or 0
end

return M
