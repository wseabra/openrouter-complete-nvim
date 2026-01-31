-- Minimal Neovim config to try openrouter-complete from the repo.
-- Neovim will IGNORE your system init (~/.config/nvim/init.lua) and use ONLY this file
-- when you pass -u on the command line.
--
-- Run from repo root:
--   nvim -u minimal_init.lua
--
-- Set OPENROUTER_API_KEY in the environment or pass api_key in setup().

local script = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(script, ":p:h")
vim.opt.rtp:prepend(root)

require("openrouter-complete").setup({
  model = "openai/gpt-oss-safeguard-20b",
  enable_on_startup = true,    -- plugin enabled when Neovim starts
  auto_trigger = true,       -- request suggestions on TextChangedI (debounced)
  log_file = "log.txt",              -- path to log file (empty = no logging)
  log_level = "debug"
  -- api_key = "your-key",  -- or use OPENROUTER_API_KEY env
})
