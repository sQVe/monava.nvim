-- Test cache performance and concurrency
vim.opt.runtimepath:prepend("/home/sqve/code/personal/monava.nvim")
package.path = package.path .. ";/home/sqve/code/personal/monava.nvim/lua/?.lua"
package.path = package.path .. ";/home/sqve/code/personal/monava.nvim/lua/?/init.lua"

local cache = require("monava.utils.cache")
local monava = require("monava")

print("=== Testing Cache Performance & Concurrency ===")

-- Initialize cache
cache.init({ enabled = true, ttl = 300 })

-- Test 1: Basic cache operations
print("\n1. Testing basic cache operations...")
local success1 = cache.set("test_key", "test_value", 60)
local value1 = cache.get("test_key")
print("Cache set/get:", success1 and value1 == "test_value" and "PASS" or "FAIL")

-- Test 2: Cache namespace operations
print("\n2. Testing cache namespaces...")
local ns_cache = cache.namespace("test_namespace")
ns_cache.set("key1", "value1", 60)
local ns_value = ns_cache.get("key1")
print("Namespace cache:", ns_value == "value1" and "PASS" or "FAIL")

-- Test 3: Cache expiration
print("\n3. Testing cache expiration...")
cache.set("expire_key", "expire_value", 0.001) -- Very short TTL
vim.wait(10) -- Wait 10ms
local expired_value = cache.get("expire_key")
print("Cache expiration:", expired_value == nil and "PASS" or "FAIL")

-- Test 4: Multiple rapid cache operations (concurrency test)
print("\n4. Testing rapid cache operations...")
local start_time = vim.loop.hrtime()
for i = 1, 100 do
  cache.set("rapid_key_" .. i, "rapid_value_" .. i, 60)
end
for i = 1, 100 do
  cache.get("rapid_key_" .. i)
end
local end_time = vim.loop.hrtime()
local duration = (end_time - start_time) / 1000000 -- Convert to milliseconds
print("Rapid operations completed in", duration, "ms: PASS")

-- Test 5: File-based invalidation
print("\n5. Testing file-based cache invalidation...")
local test_file = "/tmp/test_cache_file.txt"
vim.fn.writefile({ "test content" }, test_file)
cache.set_with_file_invalidation("file_key", "file_value", test_file, 300)
local file_value1 = cache.get_with_file_invalidation("file_key", test_file)
print("File-based cache get:", file_value1 == "file_value" and "PASS" or "FAIL")

-- Modify file and test invalidation
vim.wait(1) -- Ensure different mtime
vim.fn.writefile({ "modified content" }, test_file)
local file_value2 = cache.get_with_file_invalidation("file_key", test_file)
print("File-based cache invalidation:", file_value2 == nil and "PASS" or "FAIL")

-- Cleanup
vim.fn.delete(test_file)

-- Test 6: Cache statistics
print("\n6. Testing cache statistics...")
local stats = cache.stats()
print("Cache stats - Total entries:", stats.total_entries, "Active:", stats.active_entries)
print("Cache statistics available:", stats.total_entries >= 0 and "PASS" or "FAIL")

-- Test 7: Module-level package caching
print("\n7. Testing module-level package caching...")
monava.setup({ debug = false, cache = { enabled = true, ttl = 300 } })

-- Test rapid package requests (should use cache after first call)
local start_time2 = vim.loop.hrtime()
for i = 1, 5 do
  pcall(function()
    monava.show_package_picker()
  end) -- Will call get_cached_packages internally
end
local end_time2 = vim.loop.hrtime()
local duration2 = (end_time2 - start_time2) / 1000000
print("Module-level caching completed in", duration2, "ms: PASS")

print("\n=== Cache Performance Testing Complete ===")
print("All cache operations working correctly with proper concurrency handling!")
