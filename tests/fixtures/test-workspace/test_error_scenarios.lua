-- Test error scenarios and edge cases
vim.opt.runtimepath:prepend('/home/sqve/code/personal/monava.nvim')
package.path = package.path .. ';/home/sqve/code/personal/monava.nvim/lua/?.lua'
package.path = package.path .. ';/home/sqve/code/personal/monava.nvim/lua/?/init.lua'

local monava = require('monava')

print("=== Testing Error Scenarios ===")

-- Test 1: Invalid setup options
print("\n1. Testing invalid setup options...")
local result1 = monava.setup("invalid_string")
print("Setup with string instead of table:", result1 and "PASS" or "FAIL")

-- Test 2: Setup with valid config
print("\n2. Testing valid setup...")
local result2 = monava.setup({ debug = true })
print("Valid setup:", result2 and "PASS" or "FAIL")

-- Test 3: Test invalid package name input
print("\n3. Testing invalid package names...")
-- This should trigger input validation
pcall(function()
  monava.files("")  -- Empty string
  print("Empty package name handled gracefully: PASS")
end)

pcall(function()
  monava.files(123)  -- Number instead of string
  print("Invalid package name type handled gracefully: PASS")
end)

-- Test 4: Test dependencies with invalid input
print("\n4. Testing dependencies with invalid input...")
pcall(function()
  monava.dependencies(nil)  -- Should auto-detect and handle gracefully
  print("Dependencies with nil handled gracefully: PASS")
end)

-- Test 5: Test health check
print("\n5. Testing health check...")
pcall(function()
  monava.health()
  print("Health check executed: PASS")
end)

print("\n=== Error Scenario Testing Complete ===")