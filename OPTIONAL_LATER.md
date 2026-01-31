# Optional Features (removed from initial plan – add later if desired)

Reference list of optional items that were removed from the OpenRouter inline completion plugin plan. Use this when you want to implement them later.

---

## 1. Plugin loader file

- **What:** `plugin/openrouter-complete.lua` – Neovim loads this on startup.
- **Use:** Autocmds or one-time setup that call into the lua module (e.g. register autocmds, one-time init).

---

## 2. Model picker (UI)

- **What:** A command or keymap that lets the user pick the completion model from a list instead of setting it in `setup()`.
- **How:** Call `GET https://openrouter.ai/api/v1/models` (same curl + job approach), parse JSON, then use `vim.ui.select()` so the user picks a model; save the chosen model id in config (e.g. small cache or global option).
- **Benefit:** “Select the model” without editing config by hand.

---

## 3. Automatic trigger (CursorHold + debounce)

- **What:** Request suggestions automatically after the user stops moving the cursor for a while, instead of only on an explicit keymap.
- **How:** Use `CursorHold` or `CursorHoldI` with `vim.defer_fn()` to debounce: after N ms of no movement, call “request suggestion”. Disable when no API key or when not in insert/normal mode as appropriate.
- **Config to add:** `debounce_ms`, `trigger_events` (e.g. `CursorHold`).

---

## 4. Context: cap total character length

- **What:** Optional safety limit on the total character length of the windowed context sent to the API.
- **Where:** In `lua/openrouter-complete/context.lua`, after building the window string, cap by character count (or by estimated tokens) before sending.

---

## 5. Suggestion: “(1/3)”-style indicator

- **What:** Show which suggestion is active and how many there are (e.g. “(1/3)”).
- **Where:** Either in statusline or as extra virtual text (e.g. suffix on the same extmark or a second extmark).

---

## 6. README: “select model” flow

- **What:** Document the optional flow where the user picks the model via the model picker (command/keymap) instead of only via `setup({ model = "..." })`.
- **When:** Add this section to the README once the model picker (item 2) is implemented.
