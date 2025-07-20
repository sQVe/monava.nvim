local helpers = require("tests.helpers")

describe("adapters", function()
  local adapters
  local mock_notify

  before_each(function()
    package.loaded["monava.adapters"] = nil
    adapters = require("monava.adapters")
    mock_notify = helpers.mock_notify()
  end)

  after_each(function()
    mock_notify.restore()
    helpers.fs_rm()
  end)

  describe("picker detection", function()
    it("should detect available pickers", function()
      package.loaded["telescope"] = { setup = function() end }
      package.loaded["telescope.builtin"] = { find_files = function() end }

      local available = adapters.get_available_pickers()

      assert.is.table(available)
      assert.is_true(available.telescope)
    end)

    it("should detect fzf-lua availability", function()
      package.loaded["fzf-lua"] = {
        files = function() end,
        setup = function() end,
      }

      local available = adapters.get_available_pickers()

      assert.is.table(available)
      assert.is_true(available.fzf_lua)
    end)

    it("should detect mini.pick availability", function()
      package.loaded["mini.pick"] = {
        builtin = {
          files = function() end,
        },
        setup = function() end,
      }

      local available = adapters.get_available_pickers()

      assert.is.table(available)
      assert.is_true(available.mini_pick)
    end)

    it("should handle missing pickers gracefully", function()
      package.loaded["telescope"] = nil
      package.loaded["fzf-lua"] = nil
      package.loaded["mini.pick"] = nil

      local available = adapters.get_available_pickers()

      assert.is.table(available)
      assert.is_false(available.telescope or false)
      assert.is_false(available.fzf_lua or false)
      assert.is_false(available.mini_pick or false)
    end)
  end)

  describe("picker selection", function()
    it("should select preferred picker when available", function()
      package.loaded["telescope"] = { setup = function() end }
      package.loaded["fzf-lua"] = { setup = function() end }

      local config = {
        pickers = {
          telescope = { enabled = true },
          fzf_lua = { enabled = true },
        },
      }

      local selected = adapters.select_picker(config)

      assert.are.equal("telescope", selected)
    end)

    it("should fallback to next available picker", function()
      package.loaded["telescope"] = nil
      package.loaded["fzf-lua"] = { setup = function() end }

      local config = {
        pickers = {
          telescope = { enabled = true },
          fzf_lua = { enabled = true },
        },
      }

      local selected = adapters.select_picker(config)

      assert.are.equal("fzf_lua", selected)
    end)

    it("should respect disabled pickers", function()
      package.loaded["telescope"] = { setup = function() end }
      package.loaded["fzf-lua"] = { setup = function() end }

      local config = {
        pickers = {
          telescope = { enabled = false },
          fzf_lua = { enabled = true },
        },
      }

      local selected = adapters.select_picker(config)

      assert.are.equal("fzf_lua", selected)
    end)

    it("should return nil when no pickers available", function()
      package.loaded["telescope"] = nil
      package.loaded["fzf-lua"] = nil
      package.loaded["mini.pick"] = nil

      local config = {
        pickers = {
          telescope = { enabled = true },
          fzf_lua = { enabled = true },
          mini_pick = { enabled = true },
        },
      }

      local selected = adapters.select_picker(config)

      assert.is_nil(selected)
    end)
  end)

  describe("telescope adapter", function()
    local telescope_mock

    before_each(function()
      telescope_mock = {
        builtin = {
          find_files = function(opts) end,
        },
        extensions = {},
        setup = function() end,
      }
      package.loaded["telescope"] = telescope_mock
      package.loaded["telescope.builtin"] = telescope_mock.builtin
    end)

    it("should create package picker with telescope", function()
      local packages = {
        { name = "pkg1", path = "/workspace/packages/pkg1", type = "javascript" },
        { name = "pkg2", path = "/workspace/packages/pkg2", type = "javascript" },
      }

      local picker_config = {
        layout_strategy = "horizontal",
        prompt_title = "Select Package",
      }

      local called_with = nil
      telescope_mock.builtin.find_files = function(opts)
        called_with = opts
      end

      adapters.create_package_picker(packages, picker_config, "telescope")

      assert.is.not_nil(called_with)
      assert.are.equal("Select Package", called_with.prompt_title)
      assert.are.equal("horizontal", called_with.layout_strategy)
      assert.is.table(called_with.find_command)
    end)

    it("should handle telescope configuration merging", function()
      local packages = { { name = "test", path = "/test", type = "javascript" } }

      local default_config = {
        layout_strategy = "vertical",
        sorting_strategy = "ascending",
      }

      local user_config = {
        layout_strategy = "horizontal",
        prompt_title = "Custom Title",
      }

      local called_with = nil
      telescope_mock.builtin.find_files = function(opts)
        called_with = opts
      end

      adapters.create_package_picker(packages, user_config, "telescope", default_config)

      assert.are.equal("horizontal", called_with.layout_strategy)
      assert.are.equal("Custom Title", called_with.prompt_title)
      assert.are.equal("ascending", called_with.sorting_strategy)
    end)
  end)

  describe("configuration", function()
    it("should apply default configurations", function()
      local defaults = adapters.get_default_configs()

      assert.is.table(defaults)
      helpers.assert_has_keys(defaults, { "telescope", "fzf_lua", "mini_pick" })

      for picker, config in pairs(defaults) do
        assert.is.table(config)
        assert.is.not_nil(config.package_picker)
        assert.is.not_nil(config.current_package_picker)
      end
    end)

    it("should merge user configurations with defaults", function()
      local user_config = {
        telescope = {
          package_picker = {
            layout_strategy = "custom",
          },
        },
      }

      local merged = adapters.merge_configs(user_config)

      assert.is.table(merged)
      assert.are.equal("custom", merged.telescope.package_picker.layout_strategy)
      assert.is.table(merged.telescope.current_package_picker)
      assert.is.table(merged.fzf_lua)
      assert.is.table(merged.mini_pick)
    end)

    it("should validate picker configurations", function()
      local valid_config = {
        telescope = {
          package_picker = {
            layout_strategy = "horizontal",
          },
        },
      }

      local invalid_config = {
        telescope = {
          package_picker = "invalid",
        },
      }

      assert.is_true(adapters.validate_config(valid_config))
      assert.is_false(adapters.validate_config(invalid_config))
    end)
  end)

  describe("picker execution", function()
    local mock_ui_select

    before_each(function()
      mock_ui_select = helpers.mock_ui_select()
    end)

    after_each(function()
      mock_ui_select.restore()
    end)

    it("should execute package picker", function()
      package.loaded["telescope"] = {
        builtin = {
          find_files = function(opts) end,
        },
      }

      local packages = {
        { name = "pkg1", path = "/workspace/pkg1", type = "javascript" },
        { name = "pkg2", path = "/workspace/pkg2", type = "javascript" },
      }

      local config = {
        pickers = {
          telescope = { enabled = true },
        },
      }

      adapters.show_package_picker(packages, config)
    end)

    it("should handle picker execution errors", function()
      package.loaded["telescope"] = {
        builtin = {
          find_files = function(opts)
            error("Picker execution failed")
          end,
        },
      }

      local packages = { { name = "test", path = "/test", type = "javascript" } }
      local config = {
        pickers = {
          telescope = { enabled = true },
        },
      }

      adapters.show_package_picker(packages, config)

      assert.is_true(#mock_notify.notifications > 0)
      local error_notification = nil
      for _, notif in ipairs(mock_notify.notifications) do
        if notif.msg:match("error") or notif.msg:match("failed") then
          error_notification = notif
          break
        end
      end
      assert.is.not_nil(error_notification)
    end)
  end)

  describe("performance", function()
    it("should handle large package lists efficiently", function()
      package.loaded["telescope"] = {
        builtin = {
          find_files = function(opts) end,
        },
      }

      local large_packages = {}
      for i = 1, 1000 do
        table.insert(large_packages, {
          name = "pkg" .. i,
          path = "/workspace/packages/pkg" .. i,
          type = "javascript",
        })
      end

      local config = {
        pickers = {
          telescope = { enabled = true },
        },
      }

      local start_time = vim.loop.hrtime()
      adapters.show_package_picker(large_packages, config)
      local end_time = vim.loop.hrtime()

      local duration_ms = (end_time - start_time) / 1000000
      assert.is_true(
        duration_ms < 100,
        "Large picker creation took too long: " .. duration_ms .. "ms"
      )
    end)
  end)
end)
