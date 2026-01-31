local context = require("openrouter-complete.context")
local config = require("openrouter-complete.config")

describe("context.build", function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(true, true)
    config.merge({
      context_lines_above = 2,
      context_lines_below = 2,
    })
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  it("returns prompt with task description for buffer", function()
    -- Empty or minimal buffer: output must include task instructions
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count > 0 then
      vim.api.nvim_buf_set_lines(bufnr, 0, line_count, false, {})
    end
    local out = context.build(bufnr, 1, 1)
    assert.is_string(out)
    local has_empty_prompt = out:find("Complete the following code:")
    local has_task = out:find("Your task is to provide") or out:find("Return ONLY")
    assert.truthy(has_empty_prompt or has_task, "expected task/empty prompt, got: " .. tostring(out):sub(1, 80))
  end)

  it("includes windowed lines and truncates current line at cursor column", function()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, {
      "line1",
      "line2",
      "line3",
      "line4",
      "line5",
    })
    vim.bo[bufnr].filetype = "lua"
    local out = context.build(bufnr, 3, 3)
    assert.truthy(out:find("line1"))
    assert.truthy(out:find("line2"))
    assert.truthy(out:find("lin"))  -- line3 truncated at col 3
    assert.truthy(out:find("line4"))
    assert.truthy(out:find("line5"))
    assert.truthy(out:find("in lua"))
  end)

  it("respects context_lines_above and context_lines_below", function()
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, {
      "a", "b", "c", "d", "e", "f", "g",
    })
    config.merge({ context_lines_above = 1, context_lines_below = 1 })
    local out = context.build(bufnr, 4, 1)
    assert.truthy(out:find("d"))  -- cursor line
    assert.truthy(out:find("c"))  -- 1 above
    assert.truthy(out:find("e"))  -- 1 below
    -- "a" and "g" must not appear as context lines (substring "g" appears in "suggestions")
    assert.falsy(out:find("\na\n"))
    assert.falsy(out:find("\ng\n"))
  end)
end)
