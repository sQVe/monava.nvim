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
end)
