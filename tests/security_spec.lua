-- tests/security_spec.lua
-- Basic safety test suite for monava.nvim

local helpers = require("tests.helpers")

describe("basic safety", function()
  describe("path validation", function()
    local fs_utils

    before_each(function()
      package.loaded["monava.utils.fs"] = nil
      fs_utils = require("monava.utils.fs")
    end)

    after_each(function()
      helpers.fs_rm()
    end)

    it("should prevent basic directory traversal attempts", function()
      local dangerous_paths = {
        "../../../etc/passwd",
        "/etc/shadow",
        "../../../../../../etc/passwd",
      }

      for _, path in ipairs(dangerous_paths) do
        local result = fs_utils.exists(path)
        assert.is_false(result, "Should not allow access to: " .. path)
      end
    end)

    it("should allow legitimate workspace paths", function()
      local workspace = helpers.fs_create({
        ["package.json"] = '{"name": "legitimate-workspace"}',
        ["packages/ui/package.json"] = '{"name": "@test/ui"}',
        ["apps/web/src/index.js"] = 'console.log("test");',
      })

      local legitimate_paths = {
        workspace .. "/package.json",
        workspace .. "/packages/ui/package.json",
        workspace .. "/apps/web/src/index.js",
      }

      for _, path in ipairs(legitimate_paths) do
        assert.is_true(fs_utils.exists(path), "Should allow legitimate path: " .. path)
      end
    end)
  end)

  describe("async command validation", function()
    local utils

    before_each(function()
      package.loaded["monava.utils"] = nil
      utils = require("monava.utils")
    end)

    it("should handle basic argument validation", function()
      local invalid_arg_types = {
        { "git", function() end }, -- Function as argument
        { "npm", {} }, -- Table as argument
        { "yarn", true }, -- Boolean as argument
      }

      for _, cmd in ipairs(invalid_arg_types) do
        local handle = utils.run_async(cmd, function(code, stdout, stderr)
          assert.are.equal(-1, code, "Should reject invalid argument types")
          assert.is_true(
            stderr:find("Invalid argument type"),
            "Should report invalid argument type"
          )
        end)

        assert.is_nil(handle, "Should reject invalid argument types")
      end
    end)

    it("should handle basic timeout protection", function()
      -- Test that timeout option is accepted and reasonable
      local handle = utils.run_async({ "sleep", "1" }, function() end, {
        timeout = 5000, -- 5 second timeout
      })

      if handle and handle.cancel then
        handle.cancel() -- Clean up immediately
      end

      -- Should accept the command with timeout
      assert.is_not_nil(handle, "Should accept command with timeout")
    end)
  end)

  describe("resource limits", function()
    local utils

    before_each(function()
      package.loaded["monava.utils"] = nil
      utils = require("monava.utils")
    end)

    after_each(function()
      helpers.fs_rm()
    end)

    it("should handle reasonable directory structures", function()
      local workspace = helpers.fs_create({
        ["package.json"] = '{"name": "test-workspace"}',
        ["packages/pkg1/package.json"] = '{"name": "pkg1"}',
        ["packages/pkg2/package.json"] = '{"name": "pkg2"}',
        ["packages/pkg3/package.json"] = '{"name": "pkg3"}',
      })

      -- This should complete without issues
      local matches, is_exclusion = utils.expand_glob_pattern(workspace, "packages/*")

      assert.is_false(is_exclusion)
      assert.is.table(matches)
      assert.are.equal(3, #matches) -- Should find all 3 packages
    end)
  end)
end)
