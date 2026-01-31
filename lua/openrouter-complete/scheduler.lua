local M = {}
local config = require("openrouter-complete.config")

local timer = nil
local next_request_id = 0

--- Cancel any pending debounced trigger.
function M.cancel()
  if timer then
    timer:stop()
    timer:close()
    timer = nil
  end
end

--- Trigger a debounced callback. After debounce_ms, callback is invoked with a new request_id.
--- Call cancel() to clear pending trigger.
--- @param callback fun(request_id: number) Called after debounce with a monotonic request_id
function M.trigger(callback)
  M.cancel()
  local cfg = config.get()
  local delay = (cfg.debounce_ms and cfg.debounce_ms > 0) and cfg.debounce_ms or 500
  timer = (vim.uv or vim.loop).new_timer()
  timer:start(delay, 0, vim.schedule_wrap(function()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    next_request_id = next_request_id + 1
    callback(next_request_id)
  end))
end

--- Return the next request id without firing (for use when making a request without debounce).
function M.next_id()
  next_request_id = next_request_id + 1
  return next_request_id
end

return M
