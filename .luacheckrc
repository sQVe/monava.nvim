-- Luacheck configuration for monava.nvim

-- Global options
std = "luajit"
cache = true

-- Neovim globals
globals = {
    "vim",
}

-- Read globals (can be read but not modified)
read_globals = {
    -- Lua standard library
    "string", "table", "math", "os", "io", "package", "require",
    "pairs", "ipairs", "next", "type", "tostring", "tonumber",
    "rawget", "rawset", "rawlen", "getmetatable", "setmetatable",
    "pcall", "xpcall", "error", "assert", "select", "unpack",
    
    -- Neovim specific
    "vim",
    
    -- Test framework
    "describe", "it", "before_each", "after_each", "assert",
    "pending", "setup", "teardown", "spy", "mock", "stub",
}

-- Ignore certain warnings
ignore = {
    "212", -- Unused argument
    "213", -- Unused loop variable
    "631", -- Line is too long
}

-- Files and directories to check
files = {
    "lua/",
    "tests/",
}

-- Exclude patterns
exclude_files = {
    "tests/minimal_init.lua",
}

-- Per-file overrides
files["tests/"] = {
    std = "busted",
    ignore = {
        "111", -- Setting non-standard global variable
        "121", -- Setting read-only global variable
        "122", -- Setting read-only field of global variable  
        "212", -- Unused argument
        "213", -- Unused loop variable
        "221", -- Local variable is accessed but never set
        "631", -- Line is too long
    }
}

files["lua/"] = {
    ignore = {
        "112", -- Mutating unrelated variable
    }
}