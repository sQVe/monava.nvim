local M = {}

-- Test file system root
local fs_root = vim.fn.stdpath("cache") .. "/monava-tests"

-- Normalize path relative to test fs root
function M.path(path)
  return fs_root .. "/" .. path
end

-- Create test files and directories
function M.fs_create(files)
  vim.fn.mkdir(fs_root, "p")

  for filepath, content in pairs(files) do
    local full_path = M.path(filepath)
    local dir = vim.fn.fnamemodify(full_path, ":h")

    -- Create directory if it doesn't exist
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end

    -- Create file with content
    if type(content) == "string" then
      local file = io.open(full_path, "w")
      if file then
        file:write(content)
        file:close()
      end
    end
  end

  return fs_root
end

-- Remove test directory
function M.fs_rm(dir)
  dir = dir or fs_root
  if vim.fn.isdirectory(dir) == 1 then
    vim.fn.delete(dir, "rf")
  end
end

-- Create a temporary directory for testing
function M.create_temp_dir()
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")
  return temp_dir
end

-- Create a test file with content
function M.create_test_file(dir, filename, content)
  local filepath = dir .. "/" .. filename
  local file_dir = vim.fn.fnamemodify(filepath, ":h")

  -- Create directory if it doesn't exist
  if vim.fn.isdirectory(file_dir) == 0 then
    vim.fn.mkdir(file_dir, "p")
  end

  local file = io.open(filepath, "w")
  if file then
    file:write(content or "")
    file:close()
  end
  return filepath
end

-- Assert that a table contains expected keys
function M.assert_has_keys(tbl, expected_keys, msg)
  msg = msg or "Table missing expected keys"
  for _, key in ipairs(expected_keys) do
    assert(tbl[key] ~= nil, msg .. ': missing key "' .. key .. '"')
  end
end

-- Assert that a function throws an error
function M.assert_error(func, expected_msg)
  local ok, err = pcall(func)
  assert(not ok, "Expected function to throw an error")
  if expected_msg then
    assert(err:find(expected_msg), "Error message doesn't contain expected text: " .. err)
  end
end

-- Mock vim.notify for testing
function M.mock_notify()
  local notifications = {}
  local original_notify = vim.notify

  vim.notify = function(msg, level, opts)
    table.insert(notifications, { msg = msg, level = level, opts = opts })
  end

  return {
    notifications = notifications,
    restore = function()
      vim.notify = original_notify
    end,
  }
end

-- Mock vim.ui.select for testing
function M.mock_ui_select()
  local selections = {}
  local original_select = vim.ui.select

  vim.ui.select = function(items, opts, on_choice)
    table.insert(selections, { items = items, opts = opts })
    -- Auto-select first item for testing
    if on_choice and items and #items > 0 then
      on_choice(items[1], 1)
    end
  end

  return {
    selections = selections,
    restore = function()
      vim.ui.select = original_select
    end,
  }
end

-- Wait for condition or timeout
function M.wait_for(condition, timeout)
  timeout = timeout or 1000
  local start_time = vim.loop.hrtime()

  while not condition() do
    local elapsed = (vim.loop.hrtime() - start_time) / 1000000
    if elapsed > timeout then
      error("Timeout waiting for condition")
    end
    vim.wait(10)
  end
end

return M
