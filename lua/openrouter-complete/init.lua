local config = require("openrouter-complete.config")
local context = require("openrouter-complete.context")
local api = require("openrouter-complete.api")
local suggestion = require("openrouter-complete.suggestion")
local scheduler = require("openrouter-complete.scheduler")

local M = {}

-- Used to ignore stale completion responses (e.g. after debounced re-trigger).
local current_request_id = 0

local function do_request(request_id)
  local bufnr = vim.api.nvim_get_current_buf()
  if not config.is_enabled() or not config.is_filetype_allowed(bufnr) then
    return
  end
  suggestion.dismiss(bufnr)
  local pos = vim.api.nvim_win_get_cursor(0)
  local mode = vim.api.nvim_get_mode().mode
  local line_idx = pos[1]
  local col_idx = pos[2]

  local display_col = col_idx
  if mode:sub(1, 1) ~= "i" then
    display_col = col_idx + 1
  end
  local context_col = display_col
  local ctx = context.build(bufnr, line_idx, context_col)
  local cfg = config.get()
  local opts
  if cfg.stream then
    opts = {
      on_delta = function(accumulated_text)
        vim.schedule_wrap(function()
          if vim.api.nvim_buf_is_valid(bufnr) and request_id == current_request_id and accumulated_text and accumulated_text ~= "" then
            suggestion.update_current(bufnr, line_idx, display_col + 1, accumulated_text)
          end
        end)()
      end,
    }
  end
  api.request_completions(ctx, function(suggestions)
    if request_id ~= current_request_id then
      return
    end
    if not suggestions or #suggestions == 0 then
      return
    end
    vim.schedule_wrap(function()
      if vim.api.nvim_buf_is_valid(bufnr) and request_id == current_request_id then
        suggestion.set_suggestions(bufnr, suggestions, line_idx, display_col + 1)
      end
    end)()
  end, opts)
end

local function request_suggestion()
  current_request_id = scheduler.next_id()
  do_request(current_request_id)
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

  -- User commands: enable / disable / toggle / status
  vim.api.nvim_create_user_command("OpenRouterEnable", function()
    config.set_enabled(true)
    vim.notify("[openrouter-complete] Enabled.", vim.log.levels.INFO)
  end, { desc = "Enable OpenRouter completions" })
  vim.api.nvim_create_user_command("OpenRouterDisable", function()
    config.set_enabled(false)
    suggestion.dismiss()
    vim.notify("[openrouter-complete] Disabled.", vim.log.levels.INFO)
  end, { desc = "Disable OpenRouter completions" })
  vim.api.nvim_create_user_command("OpenRouterToggle", function()
    config.set_enabled(not config.is_enabled())
    if not config.is_enabled() then
      suggestion.dismiss()
    end
    vim.notify("[openrouter-complete] " .. (config.is_enabled() and "Enabled" or "Disabled") .. ".", vim.log.levels.INFO)
  end, { desc = "Toggle OpenRouter completions" })
  vim.api.nvim_create_user_command("OpenRouterStatus", function()
    local status = config.is_enabled() and "enabled" or "disabled"
    vim.notify("[openrouter-complete] Status: " .. status, vim.log.levels.INFO)
  end, { desc = "Show OpenRouter completion status" })

  -- Clear suggestions when cursor moves or text changes
  local group = vim.api.nvim_create_augroup("openrouter-complete", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertCharPre", "BufLeave" }, {
    group = group,
    callback = function()
      if suggestion.has_suggestion() then
        suggestion.dismiss()
      end
    end,
  })

  -- Auto-trigger: debounced completion on TextChangedI when enabled and filetype allowed
  if cfg.auto_trigger then
    vim.api.nvim_create_autocmd("TextChangedI", {
      group = group,
      callback = function()
        if not config.is_enabled() or not config.is_filetype_allowed(vim.api.nvim_get_current_buf()) then
          return
        end
        scheduler.trigger(function(rid)
          current_request_id = rid
          do_request(rid)
        end)
      end,
    })
    vim.api.nvim_create_autocmd("BufLeave", {
      group = group,
      callback = function()
        scheduler.cancel()
      end,
    })
  end

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
