local M = {}
local config = require("openrouter-complete.config")
local logger = require("openrouter-complete.logger")

local endpoint = "https://openrouter.ai/api/v1/chat/completions"

local function truncate_text(text, max_len)
  if not text or text == "" then
    return ""
  end
  if #text <= max_len then
    return text
  end
  return text:sub(1, max_len) .. "...(truncated)"
end

local function log_payload(label, text)
  if not text or text == "" then
    return
  end
  logger.debug(label .. ": " .. truncate_text(text, 2000))
end

--- Request N completion suggestions from OpenRouter.
--- When config.stream is true and opts.on_delta is provided, streams and calls on_delta(accumulated_text) then callback(suggestions).
--- @param context string User message / code context
--- @param callback fun(suggestions: string[]|nil) Called with list of suggestion strings or nil on error
--- @param opts table|nil Optional: { on_delta = function(accumulated_text: string) } for streaming
function M.request_completions(context, callback, opts)
  local cfg = config.get()
  if not config.validate(true) then
    callback(nil)
    return
  end

  opts = opts or {}
  local stream = cfg.stream and opts.on_delta
  logger.info(string.format("request_completions start model=%s stream=%s", cfg.model or "", tostring(stream)))
  logger.debug(string.format("request_context_len=%d", #context))
  log_payload("request_context", context)
  local body = vim.json.encode({
    model = cfg.model,
    messages = {
      {
        role = "system",
        content = "You are a code completion engine. Return ONLY the code that completes the snippet at the cursor. No explanations, no markdown blocks.",
      },
      { role = "user", content = context },
    },
    max_tokens = cfg.max_tokens or 256,
    temperature = cfg.temperature,
    n = stream and 1 or cfg.num_suggestions,
    stream = stream,
  })

  if stream then
    -- Streaming path: curl -N to get unbuffered output, parse SSE data: lines
    local accumulated = {}
    local stream_buffer = ""
    local jobid = vim.fn.jobstart(
      {
        "curl",
        "-s",
        "-S",
        "-N",
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
        stdout_buffered = false,
        on_stdout = function(_, data)
          local text = type(data) == "table" and table.concat(data, "") or tostring(data)
          stream_buffer = stream_buffer .. text
          local lines = {}
          for line in (stream_buffer .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(lines, line)
          end
          if stream_buffer:sub(-1) ~= "\n" and #lines > 0 then
            stream_buffer = lines[#lines]
            lines[#lines] = nil
          else
            stream_buffer = ""
          end
          for _, line in ipairs(lines) do
            if line:sub(1, 6) == "data: " then
              local payload = line:sub(7)
              if payload == "[DONE]" then
                goto continue
              end
              local ok, parsed = pcall(vim.json.decode, payload)
              if ok and parsed and parsed.choices and #parsed.choices > 0 then
                local c = parsed.choices[1]
                local idx = (c.index or 0) + 1
                if not accumulated[idx] then
                  accumulated[idx] = ""
                end
                local delta = c.delta and c.delta.content
                if delta and type(delta) == "string" then
                  accumulated[idx] = accumulated[idx] .. delta
                  vim.schedule_wrap(opts.on_delta)(accumulated[idx])
                end
              end
              ::continue::
            end
          end
        end,
        on_exit = function(_, exit_code)
          if exit_code ~= 0 then
            logger.warn("stream request failed exit_code=" .. tostring(exit_code))
            vim.notify("[openrouter-complete] Stream request failed (exit " .. exit_code .. ").", vim.log.levels.WARN)
            callback(nil)
            return
          end
          logger.info("request_completions stream done")
          local suggestions = {}
          for idx = 1, 10 do
            local s = accumulated[idx]
            if s and s ~= "" then
              s = s:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^```", ""):gsub("```$", ""):gsub("\n*$", "")
              if s ~= "" then
                table.insert(suggestions, s)
              end
            end
          end
          if #suggestions == 0 then
            callback(nil)
          else
            for i, s in ipairs(suggestions) do
              log_payload("response_suggestion[" .. i .. "]", s)
            end
            callback(suggestions)
          end
        end,
      }
    )
  if jobid <= 0 then
    logger.warn("failed to start curl job (stream)")
    vim.notify("[openrouter-complete] Failed to start curl job.", vim.log.levels.WARN)
    callback(nil)
    return
  end
  vim.fn.jobsend(jobid, body)
  vim.fn.jobclose(jobid, "stdin")
  return
end

  -- Non-streaming path
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
          logger.warn("request failed exit_code=" .. tostring(exit_code))
          vim.notify("[openrouter-complete] Request failed (exit " .. exit_code .. ").", vim.log.levels.WARN)
          callback(nil)
          return
        end
        local raw = table.concat(stdout, "\n")
        local ok, parsed = pcall(vim.json.decode, raw)
        if not ok or not parsed then
          logger.warn("invalid JSON response")
          vim.notify("[openrouter-complete] Invalid JSON response.", vim.log.levels.WARN)
          callback(nil)
          return
        end
        logger.info("request_completions done")
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
            content = content:gsub("^```%w*\n", ""):gsub("\n```$", ""):gsub("^```", ""):gsub("```$", "")
            table.insert(suggestions, (content:gsub("\n*$", "")))
          end
        end
        if #suggestions == 0 then
          callback(nil)
          return
        end
        for i, s in ipairs(suggestions) do
          log_payload("response_suggestion[" .. i .. "]", s)
        end
        if config.get().debug then
          table.insert(suggestions, "// Mock suggestion for testing\n// This is line 2\n// This is line 3")
        end
        callback(suggestions)
      end,
    }
  )

  if jobid <= 0 then
    logger.warn("failed to start curl job")
    vim.notify("[openrouter-complete] Failed to start curl job.", vim.log.levels.WARN)
    callback(nil)
    return
  end
  vim.fn.jobsend(jobid, body)
  vim.fn.jobclose(jobid, "stdin")
end

return M
