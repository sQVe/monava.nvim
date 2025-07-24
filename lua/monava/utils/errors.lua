local M = {}

M.CODES = {
  INVALID_INPUT = "E001",
  NO_MONOREPO = "E002",
  PICKER_FAILED = "E003",
  CACHE_ERROR = "E004",
}

function M.notify_error(code, message, details)
  if not code or not message then
    vim.notify("[monava:E000] Internal error: Missing error code or message", vim.log.levels.ERROR)
    return
  end

  local formatted_msg = string.format("[monava:%s] %s", code, message)

  if details then
    formatted_msg = formatted_msg .. "\nDetails: " .. tostring(details)
  end

  local level = vim.log.levels.ERROR
  if code == M.CODES.CACHE_ERROR then
    level = vim.log.levels.WARN
  end

  vim.notify(formatted_msg, level)
end

return M
