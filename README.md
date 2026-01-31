# openrouter-complete-nvim

Neovim plugin for inline code suggestions using the [OpenRouter](https://openrouter.ai/) API. Shows Copilot-style suggestions as virtual text at the cursor; you can cycle through multiple suggestions, accept one, or dismiss.

## Requirements

- **Neovim** 0.10+ recommended (for `virt_text_pos = "inline"`). Older Neovim may work but inline position may differ.
- **curl** in PATH (used for HTTP requests; no Lua HTTP dependency).

## Setup

1. Set your OpenRouter API key, e.g. in your environment:
   ```bash
   export OPENROUTER_API_KEY="your-api-key"
   ```
2. Install the plugin (packer, lazy.nvim, or clone under your rtp).
3. Call `setup()` with at least `model` (and optionally override `api_key`):

```lua
require("openrouter-complete").setup({
  model = "openai/gpt-4o-mini",  -- or any OpenRouter model id
  -- api_key = "sk-...",           -- optional override; default: OPENROUTER_API_KEY
  -- context_lines_above = 20,    -- lines above cursor in context window
  -- context_lines_below = 5,     -- lines below cursor in context window
  -- num_suggestions = 3,         -- number of suggestions to request and cycle through
  -- auto_trigger = false,       -- request suggestions on TextChangedI (debounced)
  -- debounce_ms = 500,          -- delay before auto-trigger (ms)
  -- enable_on_startup = true,    -- plugin enabled when Neovim starts
  -- filetype_allowlist = {},    -- empty = all allowed
  -- filetype_blocklist = { "help", "netrw", "NvimTree", "TelescopePrompt", "fugitive", "gitcommit", "quickfix", "prompt" },
  -- stream = false,             -- stream response and show incremental text
  -- max_tokens = 256,           -- max tokens per completion
  -- temperature = 0.1,         -- model temperature
  -- debug = false,              -- add mock suggestion when set (for testing)
  -- log_file = "",              -- path to log file (empty = no logging)
  -- log_level = "info",         -- "debug" | "info" | "warn" | "error"
  -- keymaps (optional overrides):
  -- request = "<C-Space>",
  -- accept = "<Tab>",
  -- dismiss = "<M-Esc>",
  -- next_suggestion = "<M-n>",
  -- prev_suggestion = "<M-p>",
})
```

- **OPENROUTER_API_KEY** must be set (env or in `setup`) or the plugin will warn and not send requests.
- **model** must be set (e.g. `openai/gpt-4o-mini`, `anthropic/claude-3-haiku`). Pick a model id from [OpenRouter models](https://openrouter.ai/models).

## Windowed context

Only a **window** around the cursor is sent to the API to keep token usage low:

- **context_lines_above**: number of lines above the cursor (default 20).
- **context_lines_below**: number of lines below the cursor (default 5).

The current line is sent only up to the cursor column. The full buffer is never sent.

## Multiple suggestions

- **num_suggestions** (default 3): how many completion alternatives to request in one call. You can cycle through them with the next/prev keymaps.

## Keymaps

All keymaps work in **normal and insert mode**, so you can request, accept, dismiss, and cycle suggestions while typing without leaving insert mode.

| Action            | Default     | Description                          |
| ----------------- | ----------- | ------------------------------------ |
| Request suggestion| `<C-Space>` | Request N suggestions at cursor      |
| Accept            | `<Tab>`     | Insert current suggestion and clear  |
| Dismiss           | `<M-Esc>`   | Clear suggestion without inserting   |
| Next suggestion   | `<M-n>`     | Cycle to next of N suggestions       |
| Prev suggestion   | `<M-p>`     | Cycle to previous suggestion         |

All keymaps are configurable in `setup({ ... })`. In insert mode, the **Accept** key is "smart": it will only complete the suggestion if one is visible, and perform its normal function (like inserting a tab) otherwise.

## Commands

| Command              | Description                    |
| -------------------- | ------------------------------ |
| `:OpenRouterEnable`  | Enable completions             |
| `:OpenRouterDisable` | Disable completions            |
| `:OpenRouterToggle`  | Toggle completions on/off      |
| `:OpenRouterStatus`  | Show whether enabled/disabled  |

## Auto-trigger and filetype gating

- **auto_trigger** (default `false`): when `true`, completions are requested automatically after you stop typing (debounced by **debounce_ms**).
- **filetype_blocklist**: buffer filetypes in this list never get completions. **filetype_allowlist**: when non-empty, only these filetypes get completions (blocklist still applies).

## Streaming

Set **stream** to `true` to receive the completion incrementally and show it as it arrives. When streaming, only one suggestion is requested.

## Logging

Set **log_file** to a path (e.g. `vim.fn.stdpath("cache") .. "/openrouter-complete.log"`) to append request/error logs. Use **log_level** to filter (`"debug"`, `"info"`, `"warn"`, `"error"`).

When **log_level** is `"debug"`, the plugin logs the **request context** and **response suggestions** (truncated). This can include sensitive code, so store logs accordingly.

## Minimal init (no system config)

To try the plugin without loading your normal Neovim config, use the bundled minimal init. The `-u` flag makes Neovim use **only** that file and ignore `~/.config/nvim/init.lua`:

```bash
cd /path/to/openrouter-complete-nvim
nvim -u minimal_init.lua
```

## Testing

Unit tests use [plenary.nvim](https://github.com/nvim-lua/plenary.nvim). Clone it into `deps/` then run:

```bash
git clone --depth 1 https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim
make test
```

Or: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/"`

## License

See [LICENSE](LICENSE).
