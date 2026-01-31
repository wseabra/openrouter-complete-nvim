-- Run unit tests with plenary. Usage:
--   nvim --headless -u tests/minimal_init.lua -c "lua dofile('tests/run_tests.lua')"
-- Requires plenary.nvim in deps/plenary.nvim (clone there or set rtp in minimal_init.lua).
local ok, harness = pcall(require, "plenary.test_harness")
if not ok then
  io.stderr:write("plenary.test_harness not found. Clone plenary.nvim into deps/plenary.nvim.\n")
  vim.cmd("cq 1")
  return
end
harness.run_directory("tests", { minimal = true })
