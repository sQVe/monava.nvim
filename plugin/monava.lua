-- plugin/monava.lua
-- Auto-loaded when Neovim starts
-- Handles user commands, version checking, and startup logic

if vim.fn.has('nvim-0.9.0') == 0 then
  vim.api.nvim_err_writeln('monava.nvim requires at least nvim-0.9.0.')
  return
end

-- Prevent loading twice
if vim.g.loaded_monava == 1 then
  return
end
vim.g.loaded_monava = 1

-- Create user commands with comprehensive error handling
vim.api.nvim_create_user_command('Monava', function(opts)
  local function safe_execute(fn, error_context)
    local ok, err = pcall(fn)
    if not ok then
      vim.notify('[monava] Error in ' .. error_context .. ': ' .. tostring(err), vim.log.levels.ERROR)
      if vim.g.monava_debug then
        vim.notify('[monava] Debug: ' .. debug.traceback(), vim.log.levels.DEBUG)
      end
    end
  end
  
  -- Validate and parse arguments
  local args = {}
  if opts.args and opts.args ~= '' then
    args = vim.split(vim.trim(opts.args), '%s+')
  end
  
  local subcommand = args[1]
  if not subcommand then
    vim.notify('[monava] Usage: :Monava [packages|switch|files|dependencies|info]', vim.log.levels.INFO)
    return
  end

  -- Execute subcommands with error handling
  if subcommand == 'packages' then
    safe_execute(function()
      require('monava').show_package_picker()
    end, 'packages command')
  elseif subcommand == 'switch' then
    safe_execute(function()
      require('monava').switch()
    end, 'switch command')
  elseif subcommand == 'files' then
    safe_execute(function()
      local package_name = args[2]
      require('monava').files(package_name)
    end, 'files command')
  elseif subcommand == 'dependencies' then
    safe_execute(function()
      local package_name = args[2]
      require('monava').dependencies(package_name)
    end, 'dependencies command')
  elseif subcommand == 'info' then
    safe_execute(function()
      require('monava').info()
    end, 'info command')
  else
    vim.notify('[monava] Unknown command: ' .. subcommand .. 
      '. Available: packages, switch, files, dependencies, info', vim.log.levels.WARN)
  end
end, {
  nargs = '*',
  desc = 'Monorepo navigation commands',
  complete = function(arg_lead, cmd_line, cursor_pos)
    local ok, result = pcall(function()
      local subcommands = { 'packages', 'switch', 'files', 'dependencies', 'info' }
      return vim.tbl_filter(function(cmd)
        return vim.startswith(cmd, arg_lead or '')
      end, subcommands)
    end)
    
    if ok then
      return result
    else
      return {}
    end
  end,
})

-- Optional: Create shorter alias command
vim.api.nvim_create_user_command('Mp', function(opts)
  vim.cmd('Monava ' .. opts.args)
end, {
  nargs = '*',
  desc = 'Monava packages (alias)',
  complete = function(arg_lead, cmd_line, cursor_pos)
    return vim.fn.getcompletion('Monava ' .. arg_lead, 'cmdline')
  end,
})