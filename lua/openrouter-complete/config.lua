local M = {}

local defaults = {
  api_key = nil, -- set from OPENROUTER_API_KEY or setup()
  model = "qwen/qwen3-32b",
  context_lines_above = 20,
  context_lines_below = 5,
  num_suggestions = 3,
  -- auto-trigger and gating
  auto_trigger = false,
  debounce_ms = 500,
  enable_on_startup = true,
  filetype_allowlist = {}, -- empty = all allowed
  filetype_blocklist = { "help", "netrw", "NvimTree", "TelescopePrompt", "fugitive", "gitcommit", "quickfix", "prompt" },
  -- API / model
  stream = false,
  max_tokens = 256,
  temperature = 0.1,
  -- logging
  debug = false,
  log_file = "",
  log_level = "info", -- "debug" | "info" | "warn" | "error"
  -- keymaps (can be overridden in setup)
  request = "<C-Space>",
  accept = "<Tab>",
  dismiss = "<M-Esc>",
  next_suggestion = "<M-n>",
  prev_suggestion = "<M-p>",
}

M._state = vim.deepcopy(defaults)
M._enabled = true -- plugin on/off (set by commands)

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
  -- Sync enabled state from config so enable_on_startup is applied
  M._enabled = M._state.enable_on_startup
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

--- Returns true if the plugin is enabled (not disabled via :OpenRouterDisable).
function M.is_enabled()
  return M._enabled
end

--- Set enabled state (used by Enable/Disable/Toggle commands).
function M.set_enabled(enabled)
  M._enabled = enabled
end

--- Returns true if the buffer's filetype is allowed for completions.
--- Empty allowlist = all allowed; blocklist takes precedence.
function M.is_filetype_allowed(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype or ""
  local cfg = M._state
  if ft == "" then
    return true
  end
  local blocklist = cfg.filetype_blocklist or {}
  for _, b in ipairs(blocklist) do
    if b == ft then
      return false
    end
  end
  local allowlist = cfg.filetype_allowlist or {}
  if #allowlist == 0 then
    return true
  end
  for _, a in ipairs(allowlist) do
    if a == ft then
      return true
    end
  end
  return false
end

-- Initialize from env on first load
M._state.api_key = os.getenv("OPENROUTER_API_KEY")

return M
