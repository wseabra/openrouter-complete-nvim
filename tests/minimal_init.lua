-- Minimal init for headless test runs. Sets rtp so the plugin and plenary are loadable.
local script = debug.getinfo(1, "S").source
if script:sub(1, 1) == "@" then
  script = script:sub(2)
end
local tests_dir = vim.fn.fnamemodify(script, ":p:h")
local root = vim.fn.fnamemodify(tests_dir, ":h")
vim.opt.rtp:prepend(root)
local plenary = root .. "/deps/plenary.nvim"
if vim.fn.isdirectory(plenary) == 1 then
  vim.opt.rtp:prepend(plenary)
end
