local M = {}
local config = require("openrouter-complete.config")

local endpoint = "https://openrouter.ai/api/v1/chat/completions"

--- Request N completion suggestions from OpenRouter.
--- @param context string User message / code context
--- @param callback fun(suggestions: string[]|nil) Called with list of suggestion strings or nil on error
function M.request_completions(context, callback)
  local cfg = config.get()
  if not config.validate(true) then
    callback(nil)
    return
  end

  local body = vim.json.encode({
    model = cfg.model,
    messages = {
      {
        role = "system",
        content = "You are a code completion engine. Return ONLY the code that completes the snippet at the cursor. No explanations, no markdown blocks.",
      },
      { role = "user", content = context },
    },
    max_tokens = 256,
    n = cfg.num_suggestions,
  })

  local stdout = {}
  local jobid = vim.fn.jobstart(
    {
      "curl",
      "-s",
      "-S",
      "-X",
      "POST",
      "-H",
      "Authorization: Bearer " .. cfg.api_key,
      "-H",
      "Content-Type: application/json",
      "-d",
      "@-",
      endpoint,
    },
    {
      stdin = "pipe",
      stdout_buffered = true,
      on_stdout = function(_, data)
        for _, line in ipairs(data) do
          table.insert(stdout, line)
        end
      end,
      on_exit = function(_, exit_code)
        if exit_code ~= 0 then
          vim.notify("[openrouter-complete] Request failed (exit " .. exit_code .. ").", vim.log.levels.WARN)
          callback(nil)
          return
        end
        local raw = table.concat(stdout, "\n")
        local ok, parsed = pcall(vim.json.decode, raw)
        if not ok or not parsed then
          vim.notify("[openrouter-complete] Invalid JSON response.", vim.log.levels.WARN)
          callback(nil)
          return
        end
        local choices = parsed.choices
        if not choices or #choices == 0 then
          callback(nil)
          return
        end
        local suggestions = {}
        for _, c in ipairs(choices) do
          local msg = c.message
          local content = msg and msg.content
          if content and type(content) == "string" then
            -- Strip markdown code blocks if present
            content = content:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^```", ""):gsub("```$", "")
            table.insert(suggestions, (content:gsub("\n*$", "")))
          end
        end
        if #suggestions == 0 then
          callback(nil)
          return
        end
        callback(suggestions)
      end,
    }
  )

  if jobid <= 0 then
    vim.notify("[openrouter-complete] Failed to start curl job.", vim.log.levels.WARN)
    callback(nil)
    return
  end
  vim.fn.jobsend(jobid, body)
  vim.fn.jobclose(jobid, "stdin")
end

return M
