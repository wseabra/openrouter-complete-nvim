local config = require("openrouter-complete.config")

describe("config gating", function()
  local bufnr

  before_each(function()
    bufnr = vim.api.nvim_create_buf(true, true)
    config.merge({
      filetype_allowlist = {},
      filetype_blocklist = { "help", "netrw" },
      enable_on_startup = true,
    })
  end)

  after_each(function()
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  it("is_enabled reflects set_enabled", function()
    config.set_enabled(true)
    assert.is_true(config.is_enabled())
    config.set_enabled(false)
    assert.is_false(config.is_enabled())
  end)

  it("is_filetype_allowed blocks blocklisted filetypes", function()
    vim.bo[bufnr].filetype = "help"
    assert.is_false(config.is_filetype_allowed(bufnr))
    vim.bo[bufnr].filetype = "netrw"
    assert.is_false(config.is_filetype_allowed(bufnr))
  end)

  it("is_filetype_allowed allows non-blocklisted filetypes when allowlist is empty", function()
    vim.bo[bufnr].filetype = "lua"
    assert.is_true(config.is_filetype_allowed(bufnr))
  end)

  it("is_filetype_allowed respects allowlist when non-empty", function()
    config.merge({ filetype_allowlist = { "lua" }, filetype_blocklist = {} })
    vim.bo[bufnr].filetype = "lua"
    assert.is_true(config.is_filetype_allowed(bufnr))
    vim.bo[bufnr].filetype = "python"
    assert.is_false(config.is_filetype_allowed(bufnr))
  end)
end)
