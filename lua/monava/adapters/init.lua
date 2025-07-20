-- lua/monava/adapters/init.lua
-- Picker adapter system for multi-backend support

local M = {}

-- Available picker adapters
M.available_pickers = {}
M.active_picker = nil
M.config = {}

-- Picker adapter registry
local adapters = {
  telescope = {
    name = "telescope",
    check_available = function()
      return pcall(require, "telescope")
    end,
    load = function()
      return require("telescope.builtin")
    end,
  },
  ["fzf-lua"] = {
    name = "fzf-lua",
    check_available = function()
      return pcall(require, "fzf-lua")
    end,
    load = function()
      return require("fzf-lua")
    end,
  },
  snacks = {
    name = "snacks",
    check_available = function()
      return pcall(require, "snacks")
    end,
    load = function()
      return require("snacks.picker")
    end,
  },
}

-- Initialize adapter system
function M.init(config)
  M.config = config or {}

  -- Detect available pickers based on priority
  local priority = M.config.picker_priority or { "telescope", "fzf-lua", "snacks" }

  for _, picker_name in ipairs(priority) do
    local adapter = adapters[picker_name]
    if adapter and adapter.check_available() then
      table.insert(M.available_pickers, picker_name)

      -- Set first available as active
      if not M.active_picker then
        M.active_picker = picker_name
      end
    end
  end

  if config.debug then
    vim.notify(
      "[monava] Adapter system initialized. Available: "
        .. table.concat(M.available_pickers, ", ")
        .. ". Active: "
        .. (M.active_picker or "none"),
      vim.log.levels.INFO
    )
  end
end

-- Get list of available pickers
function M.get_available_pickers()
  return M.available_pickers
end

-- Set active picker
function M.set_active_picker(picker_name)
  if vim.tbl_contains(M.available_pickers, picker_name) then
    M.active_picker = picker_name
    return true
  end
  return false
end

-- Try a picker operation with error handling
function M._try_picker_operation(picker_name, operation, ...)
  if not vim.tbl_contains(M.available_pickers, picker_name) then
    return false
  end

  local args = { ... }
  local success = false

  if picker_name == "telescope" then
    if operation == "show_packages" then
      success = pcall(M._telescope_show_packages, args[1], args[2])
    elseif operation == "switch_package" then
      success = pcall(M._telescope_switch_package, args[1], args[2])
    elseif operation == "find_files" then
      success = pcall(M._telescope_find_files, args[1], args[2])
    elseif operation == "show_dependencies" then
      success = pcall(M._telescope_show_dependencies, args[1], args[2], args[3])
    end
  elseif picker_name == "fzf-lua" then
    if operation == "show_packages" then
      success = pcall(M._fzf_show_packages, args[1], args[2])
    elseif operation == "switch_package" then
      success = pcall(M._fzf_switch_package, args[1], args[2])
    elseif operation == "find_files" then
      success = pcall(M._fzf_find_files, args[1], args[2])
    elseif operation == "show_dependencies" then
      success = pcall(M._fzf_show_dependencies, args[1], args[2], args[3])
    end
  elseif picker_name == "snacks" then
    if operation == "show_packages" then
      success = pcall(M._snacks_show_packages, args[1], args[2])
    elseif operation == "switch_package" then
      success = pcall(M._snacks_switch_package, args[1], args[2])
    elseif operation == "find_files" then
      success = pcall(M._snacks_find_files, args[1], args[2])
    elseif operation == "show_dependencies" then
      success = pcall(M._snacks_show_dependencies, args[1], args[2], args[3])
    end
  end

  return success
end

-- Show packages using active picker with fallback chain
function M.show_packages(packages)
  if not M.active_picker then
    M._fallback_show_packages(packages)
    return
  end

  local picker_config = M.config.pickers and M.config.pickers[M.active_picker] or {}

  -- Try the active picker first
  local success = M._try_picker_operation(M.active_picker, "show_packages", packages, picker_config)

  if not success then
    -- Try other available pickers as fallback
    for _, picker_name in ipairs(M.available_pickers) do
      if picker_name ~= M.active_picker then
        local fallback_config = M.config.pickers and M.config.pickers[picker_name] or {}
        success = M._try_picker_operation(picker_name, "show_packages", packages, fallback_config)
        if success then
          vim.notify("[monava] Fell back to " .. picker_name .. " picker", vim.log.levels.INFO)
          break
        end
      end
    end

    -- Final fallback to built-in implementation
    if not success then
      M._fallback_show_packages(packages)
    end
  end
end

-- Switch package using active picker with fallback chain
function M.switch_package(packages)
  if not M.active_picker then
    M._fallback_switch_package(packages)
    return
  end

  local picker_config = M.config.pickers and M.config.pickers[M.active_picker] or {}

  -- Try the active picker first
  local success =
    M._try_picker_operation(M.active_picker, "switch_package", packages, picker_config)

  if not success then
    -- Try other available pickers as fallback
    for _, picker_name in ipairs(M.available_pickers) do
      if picker_name ~= M.active_picker then
        local fallback_config = M.config.pickers and M.config.pickers[picker_name] or {}
        success = M._try_picker_operation(picker_name, "switch_package", packages, fallback_config)
        if success then
          vim.notify("[monava] Fell back to " .. picker_name .. " picker", vim.log.levels.INFO)
          break
        end
      end
    end

    -- Final fallback to built-in implementation
    if not success then
      M._fallback_switch_package(packages)
    end
  end
end

-- Find files in package using active picker with fallback chain
function M.find_files(package_info)
  if not M.active_picker then
    M._fallback_find_files(package_info)
    return
  end

  local picker_config = M.config.pickers and M.config.pickers[M.active_picker] or {}

  -- Try the active picker first
  local success =
    M._try_picker_operation(M.active_picker, "find_files", package_info, picker_config)

  if not success then
    -- Try other available pickers as fallback
    for _, picker_name in ipairs(M.available_pickers) do
      if picker_name ~= M.active_picker then
        local fallback_config = M.config.pickers and M.config.pickers[picker_name] or {}
        success = M._try_picker_operation(picker_name, "find_files", package_info, fallback_config)
        if success then
          vim.notify("[monava] Fell back to " .. picker_name .. " picker", vim.log.levels.INFO)
          break
        end
      end
    end

    -- Final fallback to built-in implementation
    if not success then
      M._fallback_find_files(package_info)
    end
  end
end

-- Show dependencies using active picker with fallback chain
function M.show_dependencies(package_name, deps)
  if not M.active_picker then
    M._fallback_show_dependencies(package_name, deps)
    return
  end

  local picker_config = M.config.pickers and M.config.pickers[M.active_picker] or {}

  -- Try the active picker first
  local success =
    M._try_picker_operation(M.active_picker, "show_dependencies", package_name, deps, picker_config)

  if not success then
    -- Try other available pickers as fallback
    for _, picker_name in ipairs(M.available_pickers) do
      if picker_name ~= M.active_picker then
        local fallback_config = M.config.pickers and M.config.pickers[picker_name] or {}
        success = M._try_picker_operation(
          picker_name,
          "show_dependencies",
          package_name,
          deps,
          fallback_config
        )
        if success then
          vim.notify("[monava] Fell back to " .. picker_name .. " picker", vim.log.levels.INFO)
          break
        end
      end
    end

    -- Final fallback to built-in implementation
    if not success then
      M._fallback_show_dependencies(package_name, deps)
    end
  end
end

-- Telescope implementations
function M._telescope_show_packages(packages, config)
  local ok, telescope = pcall(require, "telescope.pickers")
  if not ok then
    M._fallback_show_packages(packages)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  telescope
    .new(config, {
      prompt_title = "Monorepo Packages",
      finder = finders.new_table({
        results = packages,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name .. " (" .. entry.path .. ")",
            ordinal = entry.name,
          }
        end,
      }),
      sorter = conf.generic_sorter(config),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            vim.cmd("lcd " .. selection.value.path)
            vim.notify("[monava] Changed to package: " .. selection.value.name, vim.log.levels.INFO)
          end
        end)
        return true
      end,
    })
    :find()
end

function M._telescope_switch_package(packages, config)
  M._telescope_show_packages(packages, config) -- Same implementation
end

function M._telescope_find_files(package_info, config)
  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then
    M._fallback_find_files(package_info)
    return
  end

  builtin.find_files(vim.tbl_extend("keep", config, {
    prompt_title = "Files in " .. package_info.name,
    cwd = package_info.path,
  }))
end

function M._telescope_show_dependencies(package_name, deps, config)
  local ok, telescope = pcall(require, "telescope.pickers")
  if not ok then
    M._fallback_show_dependencies(package_name, deps)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  telescope
    .new(config, {
      prompt_title = "Dependencies for " .. package_name,
      finder = finders.new_table({
        results = deps,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.name .. " (" .. entry.version .. ") [" .. entry.type .. "]",
            ordinal = entry.name,
          }
        end,
      }),
      sorter = conf.generic_sorter(config),
    })
    :find()
end

-- fzf-lua implementations
function M._fzf_show_packages(packages, config)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    M._fallback_show_packages(packages)
    return
  end

  local items = {}
  for _, pkg in ipairs(packages) do
    table.insert(items, pkg.name .. " (" .. pkg.path .. ")")
  end

  fzf.fzf_exec(
    items,
    vim.tbl_extend("keep", config, {
      prompt = "Packages> ",
      actions = {
        ["default"] = function(selected)
          for _, pkg in ipairs(packages) do
            if selected[1]:match("^" .. vim.pesc(pkg.name)) then
              vim.cmd("lcd " .. pkg.path)
              vim.notify("[monava] Changed to package: " .. pkg.name, vim.log.levels.INFO)
              break
            end
          end
        end,
      },
    })
  )
end

function M._fzf_switch_package(packages, config)
  M._fzf_show_packages(packages, config) -- Same implementation
end

function M._fzf_find_files(package_info, config)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    M._fallback_find_files(package_info)
    return
  end

  fzf.files(vim.tbl_extend("keep", config, {
    prompt = "Files in " .. package_info.name .. "> ",
    cwd = package_info.path,
  }))
end

function M._fzf_show_dependencies(package_name, deps, config)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    M._fallback_show_dependencies(package_name, deps)
    return
  end

  local items = {}
  for _, dep in ipairs(deps) do
    table.insert(items, dep.name .. " (" .. dep.version .. ") [" .. dep.type .. "]")
  end

  fzf.fzf_exec(
    items,
    vim.tbl_extend("keep", config, {
      prompt = "Dependencies for " .. package_name .. "> ",
    })
  )
end

-- Snacks implementations
function M._snacks_show_packages(packages, config)
  local ok, snacks = pcall(require, "snacks.picker")
  if not ok then
    M._fallback_show_packages(packages)
    return
  end

  local items = {}
  for _, pkg in ipairs(packages) do
    table.insert(items, {
      text = pkg.name .. " (" .. pkg.path .. ")",
      value = pkg,
    })
  end

  snacks.pick(
    items,
    vim.tbl_extend("keep", config, {
      prompt = "Packages",
      on_select = function(item)
        if item then
          vim.cmd("lcd " .. item.value.path)
          vim.notify("[monava] Changed to package: " .. item.value.name, vim.log.levels.INFO)
        end
      end,
    })
  )
end

function M._snacks_switch_package(packages, config)
  M._snacks_show_packages(packages, config) -- Same implementation
end

function M._snacks_find_files(package_info, config)
  local ok, snacks = pcall(require, "snacks.picker")
  if not ok then
    M._fallback_find_files(package_info)
    return
  end

  snacks.files(vim.tbl_extend("keep", config, {
    cwd = package_info.path,
  }))
end

function M._snacks_show_dependencies(package_name, deps, config)
  local ok, snacks = pcall(require, "snacks.picker")
  if not ok then
    M._fallback_show_dependencies(package_name, deps)
    return
  end

  local items = {}
  for _, dep in ipairs(deps) do
    table.insert(items, {
      text = dep.name .. " (" .. dep.version .. ") [" .. dep.type .. "]",
      value = dep,
    })
  end

  snacks.pick(
    items,
    vim.tbl_extend("keep", config, {
      prompt = "Dependencies for " .. package_name,
    })
  )
end

-- Fallback implementations when no picker is available
function M._fallback_show_packages(packages)
  if #packages == 0 then
    vim.notify("[monava] No packages found", vim.log.levels.WARN)
    return
  end

  local lines = { "Available packages:" }
  for i, pkg in ipairs(packages) do
    table.insert(lines, string.format("%d. %s (%s)", i, pkg.name, pkg.path))
  end

  vim.ui.select(packages, {
    prompt = "Select package:",
    format_item = function(item)
      return item.name .. " (" .. item.path .. ")"
    end,
  }, function(choice)
    if choice then
      vim.cmd("lcd " .. choice.path)
      vim.notify("[monava] Changed to package: " .. choice.name, vim.log.levels.INFO)
    end
  end)
end

function M._fallback_switch_package(packages)
  M._fallback_show_packages(packages) -- Same implementation
end

function M._fallback_find_files(package_info)
  vim.cmd("edit " .. package_info.path)
  vim.notify("[monava] Opened package directory: " .. package_info.name, vim.log.levels.INFO)
end

function M._fallback_show_dependencies(package_name, deps)
  if #deps == 0 then
    vim.notify("[monava] No dependencies found for " .. package_name, vim.log.levels.INFO)
    return
  end

  local lines = { "Dependencies for " .. package_name .. ":" }
  for _, dep in ipairs(deps) do
    table.insert(lines, string.format("  %s (%s) [%s]", dep.name, dep.version, dep.type))
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "monava-deps")

  vim.cmd("split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_height(0, math.min(#lines + 2, 15))
end

return M
