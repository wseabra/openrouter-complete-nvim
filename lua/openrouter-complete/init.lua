local config = require("openrouter-complete.config")
local context = require("openrouter-complete.context")
local api = require("openrouter-complete.api")
local suggestion = require("openrouter-complete.suggestion")

local M = {}

local function request_suggestion()
  local bufnr = vim.api.nvim_get_current_buf()
  suggestion.dismiss(bufnr)
  local pos = vim.api.nvim_win_get_cursor(0)
  local mode = vim.api.nvim_get_mode().mode
  local line_idx = pos[1]
  local col_idx = pos[2]

  -- In normal mode, the cursor is ON a character. We want to complete AFTER it.
  -- In insert mode, the cursor is BETWEEN characters.
  local display_col = col_idx
  if mode:sub(1, 1) ~= "i" then
    display_col = col_idx + 1
  end

  -- Context should include all characters up to the "insertion point"
  -- For insert mode, that's col_idx characters.
  -- For normal mode, if we are after the current char, it's col_idx + 1 characters.
  local context_col = display_col

  local ctx = context.build(bufnr, line_idx, context_col)
  api.request_completions(ctx, function(suggestions)
    if not suggestions or #suggestions == 0 then
      return
    end
    vim.schedule_wrap(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        -- display_col + 1 to convert to 1-based for suggestion.lua
        suggestion.set_suggestions(bufnr, suggestions, line_idx, display_col + 1)
      end
    end)()
  end)
end

local function accept_suggestion()
  suggestion.accept()
end

local function dismiss_suggestion()
  suggestion.dismiss()
end

local function next_suggestion()
  if suggestion.has_suggestion() then
    suggestion.next()
  end
end

local function prev_suggestion()
  if suggestion.has_suggestion() then
    suggestion.prev()
  end
end

function M.request()
  request_suggestion()
end

function M.accept()
  suggestion.accept()
end

function M.dismiss()
  suggestion.dismiss()
end

function M.next()
  next_suggestion()
end

function M.prev()
  prev_suggestion()
end

function M.has_suggestion()
  return suggestion.has_suggestion()
end

function M.setup(opts)
  config.merge(opts)
  local cfg = config.get()
  local modes = { "n", "i" }

  -- Clear suggestions when cursor moves or text changes
  local group = vim.api.nvim_create_augroup("openrouter-complete", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertCharPre", "BufLeave" }, {
    group = group,
    callback = function()
      suggestion.dismiss()
    end,
  })

  if cfg.request and cfg.request ~= "" then
    vim.keymap.set(modes, cfg.request, request_suggestion, { silent = true, desc = "OpenRouter: request suggestion" })
  end
  if cfg.accept and cfg.accept ~= "" then
    -- Special handling for insert mode to allow falling back to the key's default behavior (like Tab)
    vim.keymap.set("i", cfg.accept, function()
      if suggestion.has_suggestion() then
        suggestion.accept()
      else
        -- Fallback: feed the original key without remapping to avoid infinite loops
        local key = vim.api.nvim_replace_termcodes(cfg.accept, true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
      end
    end, { silent = true, desc = "OpenRouter: accept suggestion (smart)" })
    -- For normal mode, also make it smart
    vim.keymap.set("n", cfg.accept, function()
      if suggestion.has_suggestion() then
        suggestion.accept()
      else
        local key = vim.api.nvim_replace_termcodes(cfg.accept, true, false, true)
        vim.api.nvim_feedkeys(key, "n", false)
      end
    end, { silent = true, desc = "OpenRouter: accept suggestion (smart)" })
  end
  if cfg.dismiss and cfg.dismiss ~= "" then
    vim.keymap.set(modes, cfg.dismiss, dismiss_suggestion, { silent = true, desc = "OpenRouter: dismiss suggestion" })
  end
  if cfg.next_suggestion and cfg.next_suggestion ~= "" then
    vim.keymap.set(modes, cfg.next_suggestion, next_suggestion, { silent = true, desc = "OpenRouter: next suggestion" })
  end
  if cfg.prev_suggestion and cfg.prev_suggestion ~= "" then
    vim.keymap.set(modes, cfg.prev_suggestion, prev_suggestion, { silent = true, desc = "OpenRouter: prev suggestion" })
  end
end

return M
