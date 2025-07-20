-- Minimal Neovim configuration for testing monava.nvim
vim.opt.runtimepath:prepend('/home/sqve/code/personal/monava.nvim')

-- Add package path for the plugin
package.path = package.path .. ';/home/sqve/code/personal/monava.nvim/lua/?.lua'
package.path = package.path .. ';/home/sqve/code/personal/monava.nvim/lua/?/init.lua'

-- Load the plugin
local monava = require('monava')

-- Setup plugin with debug enabled
monava.setup({
  debug = true,
  picker_priority = { 'fallback' }, -- Force fallback picker for testing
  cache = {
    enabled = true,
    ttl = 300,
  },
})

-- Create test commands for validation
vim.api.nvim_create_user_command('TestMonava', function(opts)
  local cmd = opts.args
  print("Testing monava command: " .. cmd)
  
  if cmd == 'packages' then
    monava.show_package_picker()
  elseif cmd == 'switch' then
    monava.switch()
  elseif cmd == 'files' then
    monava.files()
  elseif cmd == 'dependencies' then
    monava.dependencies()
  elseif cmd == 'info' then
    monava.info()
  elseif cmd == 'health' then
    monava.health()
  elseif cmd == 'config' then
    local config = monava.get_config()
    print(vim.inspect(config))
  else
    print("Available commands: packages, switch, files, dependencies, info, health, config")
  end
end, {
  nargs = 1,
  complete = function()
    return { 'packages', 'switch', 'files', 'dependencies', 'info', 'health', 'config' }
  end
})

print("Monava test environment loaded!")
print("Use :TestMonava <command> to test functionality")
print("Available commands: packages, switch, files, dependencies, info, health, config")