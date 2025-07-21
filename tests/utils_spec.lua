local helpers = require("tests.helpers")

describe("utils", function()
  describe("fs utilities", function()
    local fs_utils

    before_each(function()
      package.loaded["monava.utils.fs"] = nil
      fs_utils = require("monava.utils.fs")
    end)

    after_each(function()
      helpers.fs_rm()
    end)

    describe("path validation", function()
      it("should validate safe paths", function()
        local safe_paths = {
          "/home/user/project",
          "relative/path",
          "./current/dir",
          "../parent/dir",
          "/tmp/test123",
        }

        for _, path in ipairs(safe_paths) do
          assert.is_true(fs_utils.is_safe_path(path), "Path should be safe: " .. path)
        end
      end)

      it("should reject unsafe paths", function()
        local unsafe_paths = {
          "/etc/passwd",
          "/root/secret",
          "../../../etc/hosts",
          "/proc/self/environ",
          "/sys/kernel",
        }

        for _, path in ipairs(unsafe_paths) do
          assert.is_false(fs_utils.is_safe_path(path), "Path should be unsafe: " .. path)
        end
      end)

      it("should handle path traversal attempts", function()
        local traversal_paths = {
          "../../../../etc/passwd",
          "/normal/path/../../../etc/shadow",
          "project/../../../../../../root",
        }

        for _, path in ipairs(traversal_paths) do
          assert.is_false(fs_utils.is_safe_path(path), "Should block traversal: " .. path)
        end
      end)
    end)

    describe("file operations", function()
      it("should read file with size limit", function()
        local content = "Hello, World!\nThis is a test file."
        helpers.fs_create({
          ["test.txt"] = content,
        })

        local result = fs_utils.read_file_safe(helpers.path("test.txt"), 1024)
        assert.are.equal(content, result)
      end)

      it("should respect file size limits", function()
        local large_content = string.rep("x", 2000)
        helpers.fs_create({
          ["large.txt"] = large_content,
        })

        helpers.assert_error(function()
          fs_utils.read_file_safe(helpers.path("large.txt"), 1000)
        end, "File too large")
      end)

      it("should handle non-existent files", function()
        local result = fs_utils.read_file_safe(helpers.path("nonexistent.txt"))
        assert.is_nil(result)
      end)

      it("should check file existence", function()
        helpers.fs_create({
          ["exists.txt"] = "content",
        })

        assert.is_true(fs_utils.file_exists(helpers.path("exists.txt")))
        assert.is_false(fs_utils.file_exists(helpers.path("nonexistent.txt")))
      end)
    end)

    describe("directory scanning", function()
      it("should find package files by pattern", function()
        helpers.fs_create({
          ["package.json"] = '{"name": "root"}',
          ["packages/pkg1/package.json"] = '{"name": "pkg1"}',
          ["packages/pkg2/package.json"] = '{"name": "pkg2"}',
          ["node_modules/dep/package.json"] = '{"name": "dep"}',
        })

        local workspace = helpers.fs_root
        local package_files = fs_utils.find_files(workspace, "package.json")

        assert.is.table(package_files)
        assert.is_true(#package_files >= 3)

        for _, file in ipairs(package_files) do
          assert.is_false(file:match("node_modules"), "Should not include node_modules: " .. file)
        end
      end)

      it("should find files with multiple patterns", function()
        helpers.fs_create({
          ["package.json"] = '{"name": "test"}',
          ["Cargo.toml"] = '[package]\nname = "test"',
          ["go.mod"] = "module test",
        })

        local workspace = helpers.fs_root
        local patterns = { "package.json", "Cargo.toml", "go.mod" }
        local files = fs_utils.find_files(workspace, patterns)

        assert.is.table(files)
        assert.is_true(#files >= 3)
      end)

      it("should respect max_files limit", function()
        helpers.fs_create({
          ["pkg1/package.json"] = '{"name": "pkg1"}',
          ["pkg2/package.json"] = '{"name": "pkg2"}',
          ["pkg3/package.json"] = '{"name": "pkg3"}',
        })

        local workspace = helpers.fs_root
        local files = fs_utils.find_files(workspace, "package.json", { max_files = 2 })

        assert.is.table(files)
        assert.is_true(#files <= 2)
      end)

      it("should exclude ignored directories", function()
        helpers.fs_create({
          ["package.json"] = '{"name": "root"}',
          [".git/config"] = "[core]\nrepositoryformatversion = 0",
          ["node_modules/dep/package.json"] = '{"name": "dep"}',
          ["target/debug/file"] = "debug file",
        })

        local workspace = helpers.fs_root
        local files = fs_utils.find_files(workspace, "*")

        for _, file in ipairs(files) do
          assert.is_false(file:match("%.git/"), "Should not include .git: " .. file)
          assert.is_false(file:match("node_modules/"), "Should not include node_modules: " .. file)
          assert.is_false(file:match("target/"), "Should not include target: " .. file)
        end
      end)
    end)

    describe("package discovery", function()
      it("should discover JavaScript packages", function()
        helpers.fs_create({
          ["package.json"] = '{"name": "root", "workspaces": ["packages/*"]}',
          ["packages/ui/package.json"] = '{"name": "@company/ui"}',
          ["packages/utils/package.json"] = '{"name": "@company/utils"}',
          ["packages/api/package.json"] = '{"name": "@company/api"}',
        })

        local workspace = helpers.fs_root
        local packages = fs_utils.discover_packages(workspace, "javascript")

        assert.is.table(packages)
        assert.is_true(#packages >= 4)

        for _, pkg in ipairs(packages) do
          helpers.assert_has_keys(pkg, { "name", "path", "type" })
          assert.are.equal("javascript", pkg.type)
          assert.is.string(pkg.name)
          assert.is.string(pkg.path)
        end
      end)

      it("should discover Rust packages", function()
        helpers.fs_create({
          ["Cargo.toml"] = '[workspace]\nmembers = ["crates/*"]',
          ["crates/lib1/Cargo.toml"] = '[package]\nname = "lib1"',
          ["crates/lib2/Cargo.toml"] = '[package]\nname = "lib2"',
        })

        local workspace = helpers.fs_root
        local packages = fs_utils.discover_packages(workspace, "rust")

        assert.is.table(packages)
        assert.is_true(#packages >= 2)

        for _, pkg in ipairs(packages) do
          assert.are.equal("rust", pkg.type)
          assert.is_true(pkg.path:match("Cargo%.toml$"))
        end
      end)

      it("should discover all package types", function()
        helpers.fs_create({
          ["package.json"] = '{"name": "js-root", "workspaces": ["packages/*"]}',
          ["packages/ui/package.json"] = '{"name": "@company/ui"}',
          ["rust-services/auth/Cargo.toml"] = '[package]\nname = "auth-service"',
          ["go-tools/cli/go.mod"] = "module company.com/cli",
          ["java-libs/shared/pom.xml"] = "<project><artifactId>shared</artifactId></project>",
        })

        local workspace = helpers.fs_root
        local packages = fs_utils.discover_packages(workspace)

        assert.is.table(packages)
        assert.is_true(#packages >= 4)

        local types_found = {}
        for _, pkg in ipairs(packages) do
          types_found[pkg.type] = true
        end

        assert.is_true(types_found.javascript)
        assert.is_true(types_found.rust)
        assert.is_true(types_found.go)
        assert.is_true(types_found.java)
      end)

      it("should handle package parsing errors gracefully", function()
        helpers.fs_create({
          ["package.json"] = "invalid json {",
          ["Cargo.toml"] = "invalid toml [",
          ["pom.xml"] = "<invalid xml",
        })

        local workspace = helpers.fs_root
        local packages = fs_utils.discover_packages(workspace)

        assert.is.table(packages)
      end)
    end)

    describe("current package detection", function()
      it("should detect current package from file path", function()
        helpers.fs_create({
          ["package.json"] = '{"name": "root"}',
          ["packages/ui/package.json"] = '{"name": "@company/ui"}',
          ["packages/ui/src/Button.tsx"] = "export const Button = () => {};",
        })

        local workspace = helpers.fs_root
        local ui_file = helpers.path("packages/ui/src/Button.tsx")
        local current_pkg = fs_utils.get_current_package(ui_file, workspace)

        assert.is.table(current_pkg)
        assert.are.equal("@company/ui", current_pkg.name)
        assert.is_true(current_pkg.path:match("packages/ui"))
      end)

      it("should return nil for root-level files", function()
        helpers.fs_create({
          ["package.json"] = '{"name": "root"}',
          ["README.md"] = "# Project",
        })

        local workspace = helpers.fs_root
        local root_file = helpers.path("README.md")
        local current_pkg = fs_utils.get_current_package(root_file, workspace)

        assert.is_nil(current_pkg)
      end)

      it("should handle files outside workspace", function()
        helpers.fs_create({
          ["package.json"] = '{"name": "root"}',
        })

        local workspace = helpers.fs_root
        local outside_file = "/tmp/other/file.js"
        local current_pkg = fs_utils.get_current_package(outside_file, workspace)

        assert.is_nil(current_pkg)
      end)
    end)
  end)

  describe("cache utilities", function()
    local cache

    before_each(function()
      package.loaded["monava.utils.cache"] = nil
      cache = require("monava.utils.cache")

      cache.init({
        cache_dir = helpers.fs_root,
        ttl = 300,
        max_size = 100,
      })
    end)

    after_each(function()
      cache.clear_all()
      helpers.fs_rm()
    end)

    describe("basic operations", function()
      it("should set and get values", function()
        cache.set("test_key", "test_value")

        local value = cache.get("test_key")
        assert.are.equal("test_value", value)
      end)

      it("should return nil for non-existent keys", function()
        local value = cache.get("non_existent_key")
        assert.is_nil(value)
      end)

      it("should handle different data types", function()
        local test_data = {
          string_val = "hello",
          number_val = 42,
          boolean_val = true,
          table_val = { a = 1, b = 2 },
        }

        for key, value in pairs(test_data) do
          cache.set(key, value)
          assert.are.same(value, cache.get(key))
        end
      end)

      it("should overwrite existing values", function()
        cache.set("key", "value1")
        cache.set("key", "value2")

        assert.are.equal("value2", cache.get("key"))
      end)

      it("should delete values", function()
        cache.set("key_to_delete", "value")
        assert.are.equal("value", cache.get("key_to_delete"))

        cache.delete("key_to_delete")
        assert.is_nil(cache.get("key_to_delete"))
      end)
    end)

    describe("TTL and expiration", function()
      it("should respect TTL settings", function()
        cache.set("short_ttl_key", "value", 1)

        assert.are.equal("value", cache.get("short_ttl_key"))

        local cache_data = cache._get_internal_data()
        if cache_data.short_ttl_key then
          cache_data.short_ttl_key.timestamp = cache_data.short_ttl_key.timestamp - 2000
        end

        assert.is_nil(cache.get("short_ttl_key"))
      end)

      it("should clean up expired entries", function()
        cache.set("key1", "value1", 3600)
        cache.set("key2", "value2", 1)
        cache.set("key3", "value3", 1)

        local cache_data = cache._get_internal_data()
        if cache_data.key2 then
          cache_data.key2.timestamp = cache_data.key2.timestamp - 2000
        end
        if cache_data.key3 then
          cache_data.key3.timestamp = cache_data.key3.timestamp - 2000
        end

        cache.cleanup_expired()

        assert.are.equal("value1", cache.get("key1"))
        assert.is_nil(cache.get("key2"))
        assert.is_nil(cache.get("key3"))
      end)
    end)

    describe("namespace isolation", function()
      it("should isolate keys by namespace", function()
        cache.set("key", "default_value")
        cache.set("key", "namespace_value", 3600, nil, "test_namespace")

        assert.are.equal("default_value", cache.get("key"))
        assert.are.equal("namespace_value", cache.get("key", "test_namespace"))
      end)

      it("should clear namespace independently", function()
        cache.set("key1", "value1")
        cache.set("key2", "value2", 3600, nil, "ns1")
        cache.set("key3", "value3", 3600, nil, "ns2")

        cache.clear_namespace("ns1")

        assert.are.equal("value1", cache.get("key1"))
        assert.is_nil(cache.get("key2", "ns1"))
        assert.are.equal("value3", cache.get("key3", "ns2"))
      end)
    end)

    describe("size limits and LRU", function()
      it("should respect max_size limits", function()
        cache.init({
          cache_dir = helpers.fs_root,
          ttl = 300,
          max_size = 3,
        })

        cache.set("key1", "value1")
        cache.set("key2", "value2")
        cache.set("key3", "value3")
        cache.set("key4", "value4")

        assert.is_nil(cache.get("key1"))
        assert.are.equal("value2", cache.get("key2"))
        assert.are.equal("value3", cache.get("key3"))
        assert.are.equal("value4", cache.get("key4"))
      end)

      it("should count cache size correctly", function()
        cache.set("key1", "value1")
        cache.set("key2", "value2")
        cache.set("key3", "value3")

        local size = cache.size()
        assert.are.equal(3, size)

        cache.delete("key2")
        assert.are.equal(2, cache.size())
      end)
    end)

    describe("performance", function()
      it("should handle large data sets efficiently", function()
        local large_data = {}
        for i = 1, 1000 do
          large_data[i] = string.rep("x", 100)
        end

        local start_time = vim.loop.hrtime()
        cache.set("large_data", large_data)
        local retrieved = cache.get("large_data")
        local end_time = vim.loop.hrtime()

        assert.are.same(large_data, retrieved)

        local duration_ms = (end_time - start_time) / 1000000
        assert.is_true(
          duration_ms < 100,
          "Large data caching took too long: " .. duration_ms .. "ms"
        )
      end)
    end)
  end)

  describe("YAML utilities", function()
    local utils

    before_each(function()
      package.loaded["monava.utils"] = nil
      utils = require("monava.utils")
    end)

    describe("parse_pnpm_workspace_yaml", function()
      it("should parse valid PNPM workspace YAML", function()
        local yaml_content = 'packages:\n  - "packages/*"\n  - "apps/*"'
        local result, err = utils.parse_pnpm_workspace_yaml(yaml_content)

        assert.is_nil(err)
        assert.is.table(result)
        assert.is.table(result.packages)
        assert.are.equal(2, #result.packages)
        assert.are.equal("packages/*", result.packages[1])
        assert.are.equal("apps/*", result.packages[2])
      end)

      it("should handle single quoted patterns", function()
        local yaml_content = "packages:\n  - 'libs/*'\n  - 'services/*'"
        local result, err = utils.parse_pnpm_workspace_yaml(yaml_content)

        assert.is_nil(err)
        assert.is.table(result)
        assert.are.equal("libs/*", result.packages[1])
        assert.are.equal("services/*", result.packages[2])
      end)

      it("should handle unquoted patterns", function()
        local yaml_content = "packages:\n  - libs/*\n  - services/*"
        local result, err = utils.parse_pnpm_workspace_yaml(yaml_content)

        assert.is_nil(err)
        assert.is.table(result)
        assert.are.equal("libs/*", result.packages[1])
        assert.are.equal("services/*", result.packages[2])
      end)

      it("should handle exclusion patterns", function()
        local yaml_content = 'packages:\n  - "packages/*"\n  - "!**/test/**"'
        local result, err = utils.parse_pnpm_workspace_yaml(yaml_content)

        assert.is_nil(err)
        assert.is.table(result)
        assert.are.equal(2, #result.packages)
        assert.are.equal("packages/*", result.packages[1])
        assert.are.equal("!**/test/**", result.packages[2])
      end)

      it("should handle comments and empty lines", function()
        local yaml_content = [[
# This is a comment
packages:
  # Another comment
  - "packages/*"

  - "apps/*"
# Final comment
]]
        local result, err = utils.parse_pnpm_workspace_yaml(yaml_content)

        assert.is_nil(err)
        assert.is.table(result)
        assert.are.equal(2, #result.packages)
        assert.are.equal("packages/*", result.packages[1])
        assert.are.equal("apps/*", result.packages[2])
      end)

      it("should return error for invalid input types", function()
        local result, err = utils.parse_pnpm_workspace_yaml(123)
        assert.is_nil(result)
        assert.are.equal("Content must be a string", err)
      end)

      it("should return error for empty content", function()
        local result, err = utils.parse_pnpm_workspace_yaml("")
        assert.is_nil(result)
        assert.are.equal("Empty YAML content", err)
      end)

      it("should return error when no packages found", function()
        local yaml_content = "other_field:\n  - value"
        local result, err = utils.parse_pnpm_workspace_yaml(yaml_content)
        assert.is_nil(result)
        assert.are.equal("No packages found in YAML", err)
      end)

      it("should handle malformed YAML gracefully", function()
        local yaml_content = "packages:\n  - unclosed quote"
        local result, err = utils.parse_pnpm_workspace_yaml(yaml_content)
        assert.is_nil(result)
        assert.are.equal("No packages found in YAML", err)
      end)
    end)

    describe("glob_match", function()
      it("should match basic glob patterns", function()
        assert.is_true(utils.glob_match("*", "anything"))
        assert.is_true(utils.glob_match("*.js", "file.js"))
        assert.is_false(utils.glob_match("*.js", "file.ts"))
        assert.is_true(utils.glob_match("test?", "test1"))
        assert.is_false(utils.glob_match("test?", "test12"))
      end)

      it("should match directory patterns", function()
        assert.is_true(utils.glob_match("packages/*", "packages/ui"))
        assert.is_false(utils.glob_match("packages/*", "packages/ui/src"))
        assert.is_true(utils.glob_match("packages/**", "packages/ui/src/index.js"))
        assert.is_true(utils.glob_match("**/test/**", "src/test/unit"))
      end)

      it("should handle literal paths", function()
        assert.is_true(utils.glob_match("exact/path", "exact/path"))
        assert.is_false(utils.glob_match("exact/path", "other/path"))
      end)

      it("should escape special regex characters", function()
        assert.is_true(utils.glob_match("file.name", "file.name"))
        assert.is_false(utils.glob_match("file.name", "filename"))
      end)
    end)

    describe("expand_glob_pattern", function()
      local test_workspace

      before_each(function()
        test_workspace = helpers.fs_create({
          ["packages/ui/package.json"] = '{"name": "@test/ui"}',
          ["packages/utils/package.json"] = '{"name": "@test/utils"}',
          ["packages/core/package.json"] = '{"name": "@test/core"}',
          ["apps/web/package.json"] = '{"name": "web-app"}',
          ["apps/api/package.json"] = '{"name": "api-server"}',
          ["services/auth/package.json"] = '{"name": "auth-service"}',
          ["libs/shared/utils/package.json"] = '{"name": "@lib/shared-utils"}',
          ["libs/ui/components/package.json"] = '{"name": "@lib/ui-components"}',
          ["packages/test/unit/package.json"] = '{"name": "should-be-excluded"}',
          ["packages/dist/build/package.json"] = '{"name": "should-be-excluded-dist"}',
          ["node_modules/external/package.json"] = '{"name": "external-dep"}',
          -- Non-package directories (no package.json)
          ["docs/README.md"] = "Documentation",
          ["scripts/build.sh"] = "#!/bin/bash",
          ["packages/empty/index.js"] = "// No package.json",
        })
      end)

      it("should handle simple wildcard patterns", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "packages/*")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(4, #matches) -- ui, utils, core, test (dist and empty don't have package.json)

        local names = {}
        for _, match in ipairs(matches) do
          table.insert(names, match.name)
          assert.is.string(match.path)
          assert.is.string(match.relative_path)
          assert.is_true(match.relative_path:match("^packages/"))
        end

        assert.is_true(vim.tbl_contains(names, "ui"))
        assert.is_true(vim.tbl_contains(names, "utils"))
        assert.is_true(vim.tbl_contains(names, "core"))
        assert.is_true(vim.tbl_contains(names, "test"))
      end)

      it("should handle multiple directory patterns", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "apps/*")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(2, #matches) -- web, api

        local names = {}
        for _, match in ipairs(matches) do
          table.insert(names, match.name)
          assert.is_true(match.relative_path:match("^apps/"))
        end

        assert.is_true(vim.tbl_contains(names, "web"))
        assert.is_true(vim.tbl_contains(names, "api"))
      end)

      it("should handle double star recursive patterns", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "libs/**")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(2, #matches) -- shared/utils and ui/components

        local relative_paths = {}
        for _, match in ipairs(matches) do
          table.insert(relative_paths, match.relative_path)
        end

        assert.is_true(vim.tbl_contains(relative_paths, "libs/shared/utils"))
        assert.is_true(vim.tbl_contains(relative_paths, "libs/ui/components"))
      end)

      it("should detect exclusion patterns", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "!**/test/**")

        assert.is_true(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(0, #matches) -- Exclusion patterns return empty matches
      end)

      it("should respect depth limits for simple patterns", function()
        -- This tests the performance optimization that limits scanning depth
        local start_time = vim.loop.hrtime()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "packages/*")
        local end_time = vim.loop.hrtime()

        assert.is_false(is_exclusion)
        assert.are.equal(4, #matches)

        -- Should complete very quickly since it only scans 2-3 levels deep
        local duration_ms = (end_time - start_time) / 1000000
        assert.is_true(
          duration_ms < 100,
          "Simple pattern took too long: " .. duration_ms .. "ms (expected < 100ms)"
        )
      end)

      it("should handle literal path patterns", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "services/auth")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(1, #matches)
        assert.are.equal("auth", matches[1].name)
        assert.are.equal("services/auth", matches[1].relative_path)
      end)

      it("should return empty matches for non-existent patterns", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "nonexistent/*")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(0, #matches)
      end)

      it("should only return directories with package.json", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "*")

        assert.is_false(is_exclusion)
        assert.is.table(matches)

        -- Should not include docs, scripts, or packages/empty (no package.json)
        local relative_paths = {}
        for _, match in ipairs(matches) do
          table.insert(relative_paths, match.relative_path)
        end

        assert.is_false(vim.tbl_contains(relative_paths, "docs"))
        assert.is_false(vim.tbl_contains(relative_paths, "scripts"))
        assert.is_false(vim.tbl_contains(relative_paths, "packages/empty"))
      end)

      it("should handle complex nested patterns", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "libs/*/components")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(1, #matches) -- libs/ui/components
        assert.are.equal("components", matches[1].name)
        assert.are.equal("libs/ui/components", matches[1].relative_path)
      end)

      it("should handle patterns with no matches gracefully", function()
        local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, "missing/*/path")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(0, #matches)
      end)
    end)

    describe("Error recovery and edge cases", function()
      it("should handle filesystem errors gracefully", function()
        -- Test with non-existent directory
        local matches, is_exclusion = utils.expand_glob_pattern("/non/existent/path", "packages/*")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(0, #matches) -- Should return empty array, not crash
      end)

      it("should handle malformed patterns safely", function()
        local test_workspace = helpers.fs_create({
          ["packages/test/package.json"] = '{"name": "@test/pkg"}',
        })

        -- Test various potentially problematic patterns
        local problematic_patterns = {
          "", -- Empty pattern
          "/", -- Root pattern
          "//", -- Double slashes
          "**/", -- Ending with slash
          "***", -- Triple stars
          "packages/*/", -- Ending with slash
          "packages/../*", -- Path traversal attempt
        }

        for _, pattern in ipairs(problematic_patterns) do
          local matches, is_exclusion = utils.expand_glob_pattern(test_workspace, pattern)

          -- Should not crash and should return valid data
          assert.is_boolean(
            is_exclusion,
            "Pattern '" .. pattern .. "' should return boolean for is_exclusion"
          )
          assert.is.table(matches, "Pattern '" .. pattern .. "' should return table for matches")
          -- Don't assert specific counts since behavior may vary, just ensure no crash
        end
      end)

      it("should handle YAML parser edge cases", function()
        local edge_cases = {
          -- Very large content (within reasonable limits)
          {
            content = "packages:\n"
              .. string.rep("  - package" .. string.rep("x", 100) .. "\n", 50),
            should_succeed = true,
          },
          -- Unicode characters
          {
            content = 'packages:\n  - "пакеты/*"\n  - "应用/*"',
            should_succeed = true,
          },
          -- Nested structures (should be ignored but not crash)
          {
            content = "packages:\n  - apps/*\nother:\n  nested:\n    deeply:\n      - ignored",
            should_succeed = true,
          },
          -- Mixed line endings
          {
            content = "packages:\r\n  - apps/*\r\n  - packages/*\n",
            should_succeed = true,
          },
          -- Extreme nesting (should handle gracefully)
          {
            content = "packages:\n" .. string.rep("  ", 100) .. "- deeply-nested/*",
            should_succeed = false, -- Might fail due to extreme indentation
          },
        }

        for i, case in ipairs(edge_cases) do
          local result, err = utils.parse_pnpm_workspace_yaml(case.content)

          if case.should_succeed then
            assert.is_not_nil(
              result,
              "Case " .. i .. " should succeed but got error: " .. (err or "nil")
            )
            assert.is.table(result.packages, "Case " .. i .. " should return packages array")
          else
            -- For cases that might fail, just ensure they don't crash
            assert.is_boolean(result == nil, "Case " .. i .. " should return nil or valid result")
            if result == nil then
              assert.is_string(err, "Case " .. i .. " should provide error message when failing")
            end
          end
        end
      end)

      it("should handle concurrent glob expansions safely", function()
        local workspace = helpers.fs_create({
          ["packages/pkg1/package.json"] = '{"name": "@test/pkg1"}',
          ["packages/pkg2/package.json"] = '{"name": "@test/pkg2"}',
          ["packages/pkg3/package.json"] = '{"name": "@test/pkg3"}',
        })

        -- Run multiple expansions in sequence (simulating concurrent usage)
        local all_results = {}
        for i = 1, 5 do
          local matches, is_exclusion = utils.expand_glob_pattern(workspace, "packages/*")
          table.insert(all_results, { matches = matches, is_exclusion = is_exclusion })
        end

        -- All results should be consistent
        for i, result in ipairs(all_results) do
          assert.is_false(result.is_exclusion, "Result " .. i .. " should not be exclusion")
          assert.are.equal(3, #result.matches, "Result " .. i .. " should have 3 matches")
        end
      end)

      it("should handle very long path names", function()
        -- Create workspace with reasonably long path names (but not extreme)
        local long_name = string.rep("very-long-package-name-", 10) -- 230 chars
        local workspace = helpers.fs_create({
          ["packages/" .. long_name .. "/package.json"] = '{"name": "@test/' .. long_name .. '"}',
        })

        local matches, is_exclusion = utils.expand_glob_pattern(workspace, "packages/*")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        assert.are.equal(1, #matches)
        assert.are.equal(long_name, matches[1].name)
      end)

      it("should handle YAML with various invalid structures", function()
        local invalid_yamls = {
          "not_packages:\n  - value", -- Wrong key
          "packages: invalid_value", -- Wrong value type
          "packages:\n  invalid_array_item", -- Invalid array format
          "packages:\n  - \n  - valid_item", -- Empty array item
          ": invalid", -- Invalid YAML syntax
          "packages\n  - missing_colon", -- Missing colon
        }

        for i, yaml_content in ipairs(invalid_yamls) do
          local result, err = utils.parse_pnpm_workspace_yaml(yaml_content)

          -- Should fail gracefully with error message
          assert.is_nil(result, "Invalid YAML " .. i .. " should return nil")
          assert.is.string(err, "Invalid YAML " .. i .. " should provide error message")
          assert.is_true(#err > 0, "Invalid YAML " .. i .. " error message should not be empty")
        end
      end)

      it("should handle glob patterns with backslashes (Windows-style paths)", function()
        local workspace = helpers.fs_create({
          ["packages/test/package.json"] = '{"name": "@test/pkg"}',
        })

        -- Test patterns that might come from Windows environments
        local patterns = {
          "packages\\*", -- Windows-style backslash
          "packages\\test", -- Literal backslash path
          "packages/test\\*", -- Mixed slashes
        }

        for _, pattern in ipairs(patterns) do
          local matches, is_exclusion = utils.expand_glob_pattern(workspace, pattern)

          -- Should not crash, regardless of platform
          assert.is_boolean(is_exclusion)
          assert.is.table(matches)
          -- Don't assert specific behavior since path handling varies by platform
        end
      end)

      it("should handle package.json files with various encodings and content", function()
        local workspace = helpers.fs_create({
          ["packages/valid/package.json"] = '{"name": "@test/valid"}',
          ["packages/empty-json/package.json"] = "{}",
          ["packages/null-values/package.json"] = '{"name": "@test/null", "version": null}',
          ["packages/array-deps/package.json"] = '{"name": "@test/array", "dependencies": []}',
          ["packages/weird-chars/package.json"] = '{"name": "@test/\\"quoted\\"", "description": "Has \\"quotes\\""}',
        })

        local matches, is_exclusion = utils.expand_glob_pattern(workspace, "packages/*")

        assert.is_false(is_exclusion)
        assert.is.table(matches)
        -- Should find at least the valid packages, maybe more depending on error handling
        assert.is_true(#matches >= 1, "Should find at least 1 valid package")

        -- Verify the definitely valid package is found
        local found_valid = false
        for _, match in ipairs(matches) do
          if match.name == "valid" then
            found_valid = true
            break
          end
        end
        assert.is_true(found_valid, "Should find the valid package")
      end)
    end)
  end)
end)
