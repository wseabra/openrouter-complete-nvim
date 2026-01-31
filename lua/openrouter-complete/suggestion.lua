local M = {}
local api = vim.api

local ns_id = api.nvim_create_namespace("openrouter-complete")

-- Per-buffer state: { suggestions = string[], index = number, line = number, col = number, extmark_id = number|nil }
local state_by_buf = {}

local function get_state(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  if not state_by_buf[bufnr] then
    state_by_buf[bufnr] = { suggestions = {}, index = 1, line = nil, col = nil, extmark_id = nil }
  end
  return state_by_buf[bufnr]
end

local function clear_extmark(bufnr)
  local s = get_state(bufnr)
  if s.extmark_id then
    pcall(api.nvim_buf_del_extmark, bufnr, ns_id, s.extmark_id)
    s.extmark_id = nil
  end
  -- Clear all extmarks in namespace for this buffer (in case id was lost)
  local marks = api.nvim_buf_get_extmarks(bufnr, ns_id, 0, -1, {})
  for _, m in ipairs(marks) do
    api.nvim_buf_del_extmark(bufnr, ns_id, m[1])
  end
end

--- Show the current suggestion at (line, col) as inline virt_text.
--- Stores position for accept. Call after setting state.suggestions and state.index.
function M.show(bufnr, line, col)
  bufnr = bufnr or api.nvim_get_current_buf()
  local s = get_state(bufnr)
  if not s.suggestions or #s.suggestions == 0 then
    return
  end
  local idx = ((s.index - 1) % #s.suggestions) + 1
  local text = s.suggestions[idx]
  if not text or text == "" then
    return
  end
  clear_extmark(bufnr)
  s.line = line
  s.col = col
  local line_0 = line - 1
  local col_0 = math.max(0, col - 1)

  local lines = vim.split(text, "\n", true)
  local first_line = lines[1]
  local rest_lines = {}
  if #lines > 1 then
    for i = 2, #lines do
      table.insert(rest_lines, { { lines[i], "Comment" } })
    end
  end

  local opts = {
    virt_text = { { first_line, "Comment" } },
    virt_text_pos = "inline",
    virt_lines = #rest_lines > 0 and rest_lines or nil,
    id = 1,
  }
  local ok, id = pcall(api.nvim_buf_set_extmark, bufnr, ns_id, line_0, col_0, opts)
  if ok and id then
    s.extmark_id = id
  end
end

--- Set new suggestions and show first. Clears previous suggestion.
function M.set_suggestions(bufnr, suggestions, line, col)
  bufnr = bufnr or api.nvim_get_current_buf()
  clear_extmark(bufnr)
  local s = get_state(bufnr)
  s.suggestions = suggestions or {}
  s.index = 1
  s.line = line
  s.col = col
  if #s.suggestions > 0 then
    M.show(bufnr, line, col)
  end
end

--- Cycle to next suggestion. Redraws extmark.
function M.next(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local s = get_state(bufnr)
  if #s.suggestions == 0 then
    return
  end
  s.index = ((s.index) % #s.suggestions) + 1
  if s.line and s.col then
    M.show(bufnr, s.line, s.col)
  end
end

--- Cycle to previous suggestion. Redraws extmark.
function M.prev(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local s = get_state(bufnr)
  if #s.suggestions == 0 then
    return
  end
  s.index = s.index - 1
  if s.index < 1 then
    s.index = #s.suggestions
  end
  if s.line and s.col then
    M.show(bufnr, s.line, s.col)
  end
end

--- Dismiss: clear extmark and state. No insert.
function M.dismiss(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  clear_extmark(bufnr)
  state_by_buf[bufnr] = { suggestions = {}, index = 1, line = nil, col = nil, extmark_id = nil }
end

--- Accept: insert current suggestion at stored (line, col), then clear.
function M.accept(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local s = get_state(bufnr)
  if #s.suggestions == 0 or not s.line or not s.col then
    M.dismiss(bufnr)
    return
  end
  local idx = ((s.index - 1) % #s.suggestions) + 1
  local text = s.suggestions[idx]
  if not text or text == "" then
    M.dismiss(bufnr)
    return
  end
  clear_extmark(bufnr)
  -- nvim_buf_set_text uses 0-based (start_row, start_col, end_row, end_col); replacement is list of lines
  local line_0 = s.line - 1
  local col_0 = math.max(0, s.col - 1)
  local lines = vim.split(text, "\n", true)
  pcall(api.nvim_buf_set_text, bufnr, line_0, col_0, line_0, col_0, lines)

  -- Move cursor to the end of the inserted text
  local end_line = line_0 + #lines
  local end_col = #lines == 1 and (col_0 + #lines[1]) or #lines[#lines]
  pcall(api.nvim_win_set_cursor, 0, { end_line, end_col })

  state_by_buf[bufnr] = { suggestions = {}, index = 1, line = nil, col = nil, extmark_id = nil }
end

--- Return true if this buffer has an active suggestion.
function M.has_suggestion(bufnr)
  bufnr = bufnr or api.nvim_get_current_buf()
  local s = get_state(bufnr)
  return #s.suggestions > 0
end

return M
