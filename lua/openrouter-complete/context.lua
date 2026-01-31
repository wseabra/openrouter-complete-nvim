local M = {}
local config = require("openrouter-complete.config")

--- Build windowed context around cursor: N lines above + N lines below.
--- Current line is included only up to cursor column.
--- @param bufnr number
--- @param cursor_line number 1-based
--- @param cursor_col number 1-based
--- @return string
function M.build(bufnr, cursor_line, cursor_col)
  local cfg = config.get()
  local above = cfg.context_lines_above
  local below = cfg.context_lines_below
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local total = #lines
  if total == 0 then
    return "Complete the following code:\n\n"
  end

  local row = cursor_line - 1 -- 0-based
  local start_row = math.max(0, row - above)
  local end_row = math.min(total - 1, row + below)

  local parts = {}
  for i = start_row, end_row do
    local line = lines[i + 1] or ""
    if i < row then
      table.insert(parts, line)
    elseif i == row then
      -- prefix up to cursor_col characters
      local prefix = line:sub(1, cursor_col)
      table.insert(parts, prefix)
    else
      table.insert(parts, line)
    end
  end

  local ft = vim.bo[bufnr].filetype
  local lang = ft and ft ~= "" and (" in " .. ft) or ""
  return table.concat({
    "Your task is to provide code completion suggestions" .. lang .. ".",
    "Return ONLY the code that should follow the cursor position.",
    "Do NOT provide explanations, do NOT wrap in markdown blocks, and do NOT repeat the existing code.",
    "Context:",
    table.concat(parts, "\n"),
  }, "\n")
end

return M
