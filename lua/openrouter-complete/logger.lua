local M = {}
local config = require("openrouter-complete.config")

local function level_num(level)
  local order = { debug = 1, info = 2, warn = 3, error = 4 }
  return order[level] or 2
end

local function format_line(level, msg)
  local t = os.date("!%Y-%m-%dT%H:%M:%SZ")
  return string.format("[%s] [%s] %s\n", t, level:upper(), msg)
end

--- Append a log line to the configured log file. No-op if log_file is not set.
--- Non-blocking: uses vim.loop to write asynchronously.
function M.log(level, msg)
  local cfg = config.get()
  if not cfg or not cfg.log_file or cfg.log_file == "" then
    return
  end
  local min_level = level_num(cfg.log_level or "info")
  if level_num(level) < min_level then
    return
  end
  local line = format_line(level, msg)
  local path = cfg.log_file
  local uv = vim.uv or vim.loop
  uv.fs_open(path, "a", 438, function(err, fd)
    if err or not fd then
      return
    end
    uv.fs_write(fd, line, -1, function()
      uv.fs_close(fd)
    end)
  end)
end

function M.debug(msg)
  M.log("debug", msg)
end

function M.info(msg)
  M.log("info", msg)
end

function M.warn(msg)
  M.log("warn", msg)
end

function M.error(msg)
  M.log("error", msg)
end

return M
