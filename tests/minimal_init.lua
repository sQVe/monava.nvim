#!/usr/bin/env -S nvim -l

-- Set test environment
vim.env.LAZY_STDPATH = ".tests"

-- Clone lazy.nvim if not already present
local function clone_lazy()
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "--branch=stable",
      lazyrepo,
      lazypath,
    })
  end
  vim.opt.rtp:prepend(lazypath)
end

-- Set up lazy.nvim
clone_lazy()

-- Initialize lazy with the current plugin
require("lazy").setup({
  { dir = vim.fn.getcwd() },
}, {
  lockfile = vim.fn.stdpath("cache") .. "/lazy-lock.json",
})

-- Run tests if in minitest mode
if vim.v.argv[1] == "--minitest" then
  -- Load busted and run tests
  require("busted.runner")({ standalone = false })
end
