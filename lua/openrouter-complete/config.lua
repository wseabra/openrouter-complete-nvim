local M = {}

local defaults = {
  api_key = nil, -- set from OPENROUTER_API_KEY or setup()
  model = "openai/gpt-4o-mini",
  context_lines_above = 20,
  context_lines_below = 5,
  num_suggestions = 3,
  -- keymaps (can be overridden in setup)
  request = "<C-Space>",
  accept = "<Tab>",
  dismiss = "<M-Esc>",
  next_suggestion = "<M-n>",
  prev_suggestion = "<M-p>",
}

M._state = vim.deepcopy(defaults)

function M.merge(opts)
  opts = opts or {}
  for k, v in pairs(opts) do
    if M._state[k] ~= nil then
      M._state[k] = v
    end
  end
  -- Always resolve api_key: prefer opts, then env
  if opts.api_key ~= nil then
    M._state.api_key = opts.api_key
  elseif M._state.api_key == nil then
    M._state.api_key = os.getenv("OPENROUTER_API_KEY")
  end
end

function M.get()
  return M._state
end

--- Returns true if config is valid for making a request (api_key and model set).
--- Optionally notifies the user if invalid.
function M.validate(notify)
  local api_key = M._state.api_key
  local model = M._state.model
  if not api_key or api_key == "" then
    if notify then
      vim.notify("[openrouter-complete] OPENROUTER_API_KEY is not set.", vim.log.levels.WARN)
    end
    return false
  end
  if not model or model == "" then
    if notify then
      vim.notify("[openrouter-complete] model is not set.", vim.log.levels.WARN)
    end
    return false
  end
  return true
end

-- Initialize from env on first load
M._state.api_key = os.getenv("OPENROUTER_API_KEY")

return M
