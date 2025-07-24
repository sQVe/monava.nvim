local M = {}

M.PACKAGE_NAME_PATTERN = "^[%w@][%w@%-%./]*$"
M.MAX_PACKAGE_NAME_LENGTH = 255

function M.validate_package_name(name)
  if name == nil then
    return false, "Package name cannot be nil"
  end

  if type(name) ~= "string" then
    return false, "Package name must be a string"
  end

  if name == "" then
    return false, "Package name cannot be empty"
  end

  if #name > M.MAX_PACKAGE_NAME_LENGTH then
    return false, "Package name too long (max " .. M.MAX_PACKAGE_NAME_LENGTH .. " characters)"
  end

  if not name:match(M.PACKAGE_NAME_PATTERN) then
    return false, "Invalid package name format"
  end

  return true, nil
end

function M.validate_config(config)
  if config == nil then
    return false, "Configuration cannot be nil"
  end

  if type(config) ~= "table" then
    return false, "Configuration must be a table"
  end

  if next(config) == nil then
    return false, "Configuration cannot be empty"
  end

  return true, nil
end

function M.validate_picker_opts(opts)
  if opts == nil then
    return true, nil
  end

  if type(opts) ~= "table" then
    return false, "Picker options must be a table"
  end

  if opts.timeout and (type(opts.timeout) ~= "number" or opts.timeout <= 0) then
    return false, "Picker timeout must be a positive number"
  end

  if opts.max_results and (type(opts.max_results) ~= "number" or opts.max_results <= 0) then
    return false, "Picker max_results must be a positive number"
  end

  return true, nil
end

return M
