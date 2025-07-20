local helpers = require("tests.helpers")

describe("config", function()
  local config

  before_each(function()
    package.loaded["monava.config"] = nil
    config = require("monava.config")
  end)

  after_each(function()
    helpers.fs_rm()
  end)

  describe("defaults", function()
    it("should have all required fields", function()
      local defaults = config.defaults

      helpers.assert_has_keys(defaults, {
        "pickers",
        "keymaps",
        "cache",
        "ui",
        "performance",
      })
    end)

    it("should have valid picker configurations", function()
      local pickers = config.defaults.pickers

      helpers.assert_has_keys(pickers, {
        "telescope",
        "fzf_lua",
        "mini_pick",
      })

      for picker_name, picker_config in pairs(pickers) do
        assert.is.table(picker_config)
        assert.is.boolean(picker_config.enabled)
        assert.is.table(picker_config.config)
      end
    end)

    it("should have valid keymap configuration", function()
      local keymaps = config.defaults.keymaps

      helpers.assert_has_keys(keymaps, {
        "enable",
        "prefix",
        "mappings",
      })

      assert.is.boolean(keymaps.enable)
      assert.is.string(keymaps.prefix)
      assert.is.table(keymaps.mappings)
    end)

    it("should have valid cache configuration", function()
      local cache_config = config.defaults.cache

      helpers.assert_has_keys(cache_config, {
        "enabled",
        "ttl",
        "max_size",
      })

      assert.is.boolean(cache_config.enabled)
      assert.is.number(cache_config.ttl)
      assert.is.number(cache_config.max_size)
    end)
  end)

  describe("merge_config", function()
    it("should merge user config with defaults", function()
      local user_config = {
        pickers = {
          telescope = {
            enabled = false,
          },
        },
        cache = {
          ttl = 1800,
        },
      }

      local merged = config.merge_config(user_config)

      assert.is_false(merged.pickers.telescope.enabled)
      assert.are.equal(1800, merged.cache.ttl)
      assert.is.table(merged.pickers.telescope.config)
      assert.is.boolean(merged.cache.enabled)
    end)

    it("should handle deep nested merging", function()
      local user_config = {
        pickers = {
          telescope = {
            config = {
              layout_strategy = "vertical",
            },
          },
        },
      }

      local merged = config.merge_config(user_config)

      assert.are.equal("vertical", merged.pickers.telescope.config.layout_strategy)
      assert.is.not_nil(merged.pickers.telescope.config.layout_config)
    end)

    it("should handle nil user config", function()
      local merged = config.merge_config(nil)

      assert.are.same(config.defaults, merged)
    end)

    it("should handle empty user config", function()
      local merged = config.merge_config({})

      assert.are.same(config.defaults, merged)
    end)
  end)

  describe("validate_config", function()
    it("should validate valid configuration", function()
      local valid_config = {
        pickers = {
          telescope = {
            enabled = true,
            config = {},
          },
        },
        cache = {
          enabled = true,
          ttl = 900,
        },
      }

      local is_valid, errors = config.validate_config(valid_config)
      assert.is_true(is_valid)
      assert.is_nil(errors)
    end)

    it("should reject invalid picker configuration", function()
      local invalid_config = {
        pickers = {
          telescope = {
            enabled = "invalid",
          },
        },
      }

      local is_valid, errors = config.validate_config(invalid_config)
      assert.is_false(is_valid)
      assert.is.table(errors)
    end)

    it("should reject invalid cache TTL", function()
      local invalid_config = {
        cache = {
          ttl = -100,
        },
      }

      local is_valid, errors = config.validate_config(invalid_config)
      assert.is_false(is_valid)
      assert.is.table(errors)
    end)
  end)

  describe("setup_keymaps", function()
    local mock_keymap_set

    before_each(function()
      mock_keymap_set = {}
      vim.keymap.set = function(mode, lhs, rhs, opts)
        table.insert(mock_keymap_set, {
          mode = mode,
          lhs = lhs,
          rhs = rhs,
          opts = opts,
        })
      end
    end)

    it("should set up keymaps when enabled", function()
      local test_config = {
        keymaps = {
          enable = true,
          prefix = "<leader>m",
          mappings = {
            packages = "p",
            current = "c",
          },
        },
      }

      config.setup_keymaps(test_config)

      assert.is_true(#mock_keymap_set > 0)

      local package_mapping = nil
      local current_mapping = nil

      for _, mapping in ipairs(mock_keymap_set) do
        if mapping.lhs == "<leader>mp" then
          package_mapping = mapping
        elseif mapping.lhs == "<leader>mc" then
          current_mapping = mapping
        end
      end

      assert.is.not_nil(package_mapping)
      assert.is.not_nil(current_mapping)
      assert.are.equal("n", package_mapping.mode)
      assert.are.equal("n", current_mapping.mode)
    end)

    it("should not set up keymaps when disabled", function()
      local test_config = {
        keymaps = {
          enable = false,
          prefix = "<leader>m",
          mappings = {
            packages = "p",
          },
        },
      }

      config.setup_keymaps(test_config)

      assert.are.equal(0, #mock_keymap_set)
    end)
  end)

  describe("get_active_picker", function()
    it("should get active picker configuration", function()
      local test_config = {
        pickers = {
          telescope = {
            enabled = true,
            config = { test = "value" },
          },
          fzf_lua = {
            enabled = false,
            config = {},
          },
        },
      }

      local active_picker, picker_config = config.get_active_picker(test_config)

      assert.are.equal("telescope", active_picker)
      assert.are.same({ test = "value" }, picker_config)
    end)

    it("should handle no enabled pickers", function()
      local test_config = {
        pickers = {
          telescope = { enabled = false },
          fzf_lua = { enabled = false },
        },
      }

      local active_picker, picker_config = config.get_active_picker(test_config)

      assert.is_nil(active_picker)
      assert.is_nil(picker_config)
    end)
  end)
end)
