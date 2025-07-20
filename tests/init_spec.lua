local helpers = require("tests.helpers")

describe("monava", function()
  local monava
  local mock_notify
  local mock_ui_select

  before_each(function()
    package.loaded["monava"] = nil
    package.loaded["monava.config"] = nil
    package.loaded["monava.core"] = nil
    package.loaded["monava.adapters"] = nil

    monava = require("monava")
    mock_notify = helpers.mock_notify()
    mock_ui_select = helpers.mock_ui_select()
  end)

  after_each(function()
    mock_notify.restore()
    mock_ui_select.restore()
    helpers.fs_rm()
  end)

  describe("setup", function()
    it("should initialize with default configuration", function()
      monava.setup()
    end)

    it("should initialize with user configuration", function()
      local user_config = {
        keymaps = {
          enable = false,
        },
        cache = {
          enabled = false,
        },
        pickers = {
          telescope = {
            enabled = true,
            config = {
              layout_strategy = "vertical",
            },
          },
        },
      }

      monava.setup(user_config)
    end)

    it("should validate user configuration", function()
      local invalid_config = {
        keymaps = {
          enable = "invalid",
        },
      }

      helpers.assert_error(function()
        monava.setup(invalid_config)
      end)
    end)

    it("should set up keymaps when enabled", function()
      local mock_keymap_set = {}
      vim.keymap.set = function(mode, lhs, rhs, opts)
        table.insert(mock_keymap_set, { mode = mode, lhs = lhs, rhs = rhs, opts = opts })
      end

      monava.setup({
        keymaps = {
          enable = true,
          prefix = "<leader>m",
          mappings = {
            packages = "p",
            current = "c",
          },
        },
      })

      assert.is_true(#mock_keymap_set > 0)

      local has_package_mapping = false
      local has_current_mapping = false

      for _, mapping in ipairs(mock_keymap_set) do
        if mapping.lhs == "<leader>mp" then
          has_package_mapping = true
        elseif mapping.lhs == "<leader>mc" then
          has_current_mapping = true
        end
      end

      assert.is_true(has_package_mapping)
      assert.is_true(has_current_mapping)
    end)

    it("should not set up keymaps when disabled", function()
      local mock_keymap_set = {}
      vim.keymap.set = function(mode, lhs, rhs, opts)
        table.insert(mock_keymap_set, { mode = mode, lhs = lhs, rhs = rhs, opts = opts })
      end

      monava.setup({
        keymaps = {
          enable = false,
        },
      })

      assert.are.equal(0, #mock_keymap_set)
    end)

    it("should create user commands", function()
      monava.setup()

      local commands = vim.api.nvim_get_commands({})

      assert.is.not_nil(commands.MonavaPackages)
      assert.is.not_nil(commands.MonavaCurrent)
    end)

    it("should handle multiple initialization calls", function()
      monava.setup()

      monava.setup({
        cache = {
          enabled = false,
        },
      })
    end)
  end)

  describe("packages command", function()
    before_each(function()
      helpers.fs_create({
        ["package.json"] = '{"name": "root", "workspaces": ["packages/*"]}',
        ["packages/ui/package.json"] = '{"name": "@company/ui"}',
        ["packages/api/package.json"] = '{"name": "@company/api"}',
        ["packages/utils/package.json"] = '{"name": "@company/utils"}',
      })

      package.loaded["telescope"] = {
        builtin = {
          find_files = function(opts) end,
        },
      }

      vim.cmd("cd " .. helpers.fs_root)
    end)

    it("should show package picker", function()
      monava.setup({
        pickers = {
          telescope = { enabled = true },
        },
      })

      local telescope_called = false
      package.loaded["telescope"].builtin.find_files = function(opts)
        telescope_called = true
        assert.is.table(opts)
        assert.is.string(opts.prompt_title)
      end

      monava.packages()

      assert.is_true(telescope_called)
    end)

    it("should handle non-monorepo directories", function()
      local single_project = helpers.fs_create({
        ["package.json"] = '{"name": "single-project"}',
      })

      vim.cmd("cd " .. single_project)

      monava.setup()
      monava.packages()

      assert.is_true(#mock_notify.notifications > 0)
      local has_monorepo_warning = false
      for _, notif in ipairs(mock_notify.notifications) do
        if notif.msg:match("monorepo") or notif.msg:match("packages") then
          has_monorepo_warning = true
          break
        end
      end
      assert.is_true(has_monorepo_warning)
    end)

    it("should handle no available pickers", function()
      package.loaded["telescope"] = nil
      package.loaded["fzf-lua"] = nil
      package.loaded["mini.pick"] = nil

      monava.setup()
      monava.packages()

      assert.is_true(#mock_notify.notifications > 0)
      local has_picker_warning = false
      for _, notif in ipairs(mock_notify.notifications) do
        if notif.msg:match("picker") or notif.msg:match("install") then
          has_picker_warning = true
          break
        end
      end
      assert.is_true(has_picker_warning)
    end)

    it("should apply package filtering", function()
      monava.setup({
        pickers = {
          telescope = { enabled = true },
        },
      })

      local packages_passed = nil
      package.loaded["telescope"].builtin.find_files = function(opts)
        packages_passed = opts
      end

      monava.packages({ type = "javascript" })

      assert.is.not_nil(packages_passed)
    end)
  end)

  describe("current command", function()
    before_each(function()
      helpers.fs_create({
        ["package.json"] = '{"name": "root", "workspaces": ["packages/*"]}',
        ["packages/ui/package.json"] = '{"name": "@company/ui"}',
        ["packages/ui/src/Button.tsx"] = "export const Button = () => {};",
        ["packages/api/package.json"] = '{"name": "@company/api"}',
        ["packages/api/routes/users.js"] = "module.exports = router;",
      })

      package.loaded["telescope"] = {
        builtin = {
          find_files = function(opts) end,
        },
      }

      vim.cmd("cd " .. helpers.fs_root)
    end)

    it("should show current package picker", function()
      vim.api.nvim_buf_get_name = function()
        return helpers.path("packages/ui/src/Button.tsx")
      end

      monava.setup({
        pickers = {
          telescope = { enabled = true },
        },
      })

      local telescope_called = false
      local current_package_opts = nil
      package.loaded["telescope"].builtin.find_files = function(opts)
        telescope_called = true
        current_package_opts = opts
      end

      monava.current()

      assert.is_true(telescope_called)
      assert.is.not_nil(current_package_opts)
      assert.is_true(current_package_opts.cwd:match("packages/ui"))
    end)

    it("should handle files not in a package", function()
      vim.api.nvim_buf_get_name = function()
        return helpers.path("package.json")
      end

      monava.setup()
      monava.current()

      assert.is_true(#mock_notify.notifications > 0)
      local has_no_package_warning = false
      for _, notif in ipairs(mock_notify.notifications) do
        if notif.msg:match("package") or notif.msg:match("current") then
          has_no_package_warning = true
          break
        end
      end
      assert.is_true(has_no_package_warning)
    end)

    it("should handle buffers with no name", function()
      vim.api.nvim_buf_get_name = function()
        return ""
      end

      monava.setup()
      monava.current()

      assert.is_true(#mock_notify.notifications > 0)
    end)
  end)

  describe("commands", function()
    it("should execute MonavaPackages command", function()
      monava.setup()

      vim.cmd("MonavaPackages")
    end)

    it("should execute MonavaCurrent command", function()
      monava.setup()

      vim.cmd("MonavaCurrent")
    end)

    it("should handle command arguments", function()
      monava.setup()

      vim.cmd("MonavaPackages javascript")
    end)
  end)

  describe("error handling", function()
    it("should handle initialization errors gracefully", function()
      local original_require = require
      require = function(module)
        if module == "monava.config" then
          error("Config loading failed")
        end
        return original_require(module)
      end

      helpers.assert_error(function()
        monava.setup()
      end, "Config loading failed")

      require = original_require
    end)

    it("should recover from picker errors", function()
      package.loaded["telescope"] = {
        builtin = {
          find_files = function(opts)
            error("Picker failed")
          end,
        },
      }

      helpers.fs_create({
        ["package.json"] = '{"name": "root", "workspaces": ["packages/*"]}',
        ["packages/test/package.json"] = '{"name": "test"}',
      })
      vim.cmd("cd " .. helpers.fs_root)

      monava.setup({
        pickers = {
          telescope = { enabled = true },
        },
      })

      monava.packages()

      assert.is_true(#mock_notify.notifications > 0)
    end)

    it("should handle workspace detection failures", function()
      local restricted_dir = helpers.create_temp_dir()
      vim.cmd("cd " .. restricted_dir)

      monava.setup()
      monava.packages()

      assert.is_true(#mock_notify.notifications > 0)

      helpers.fs_rm(restricted_dir)
    end)

    it("should provide helpful error messages", function()
      monava.setup()
      monava.packages()

      assert.is_true(#mock_notify.notifications > 0)
      local helpful_message = false
      for _, notif in ipairs(mock_notify.notifications) do
        if
          notif.msg:match("monorepo") and (notif.msg:match("support") or notif.msg:match("detect"))
        then
          helpful_message = true
          break
        end
      end
      assert.is_true(helpful_message)
    end)
  end)

  describe("performance", function()
    it("should handle large workspaces efficiently", function()
      local large_workspace = {}
      large_workspace["package.json"] = '{"name": "large", "workspaces": ["packages/*"]}'

      for i = 1, 50 do
        large_workspace["packages/pkg" .. i .. "/package.json"] = '{"name": "pkg' .. i .. '"}'
      end

      helpers.fs_create(large_workspace)
      vim.cmd("cd " .. helpers.fs_root)

      package.loaded["telescope"] = {
        builtin = {
          find_files = function(opts) end,
        },
      }

      monava.setup({
        pickers = {
          telescope = { enabled = true },
        },
      })

      local start_time = vim.loop.hrtime()
      monava.packages()
      local end_time = vim.loop.hrtime()

      local duration_ms = (end_time - start_time) / 1000000
      assert.is_true(
        duration_ms < 1000,
        "Large workspace handling took too long: " .. duration_ms .. "ms"
      )
    end)

    it("should cache workspace analysis", function()
      helpers.fs_create({
        ["package.json"] = '{"name": "root", "workspaces": ["packages/*"]}',
        ["packages/ui/package.json"] = '{"name": "ui"}',
      })
      vim.cmd("cd " .. helpers.fs_root)

      package.loaded["telescope"] = {
        builtin = {
          find_files = function(opts) end,
        },
      }

      monava.setup({
        cache = {
          enabled = true,
        },
        pickers = {
          telescope = { enabled = true },
        },
      })

      local start_time = vim.loop.hrtime()
      monava.packages()
      local end_time = vim.loop.hrtime()
      local first_duration = end_time - start_time

      start_time = vim.loop.hrtime()
      monava.packages()
      end_time = vim.loop.hrtime()
      local second_duration = end_time - start_time

      assert.is_true(second_duration <= first_duration)
    end)
  end)
end)
