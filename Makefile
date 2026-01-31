# Run unit tests. Requires plenary.nvim: git clone --depth 1 https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim
test:
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/"

.PHONY: test
