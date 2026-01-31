-- Entry point for the plugin when loaded via runtimepath
-- This file is loaded automatically by Neovim when the plugin is installed

if vim.fn.has("nvim-0.9.0") == 0 then
  vim.api.nvim_err_writeln("openrouter-complete requires at least Neovim 0.9.0")
  return
end

-- Prevent loading the plugin twice
if vim.g.loaded_openrouter_complete then
  return
end
vim.g.loaded_openrouter_complete = true
