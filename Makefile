TESTS_INIT=tests/minimal_init.lua
TESTS_DIR=tests/

.PHONY: test

# Run unit tests. Requires plenary.nvim: git clone --depth 1 https://github.com/nvim-lua/plenary.nvim deps/plenary.nvim
test:
	@nvim \
		--headless \
		--noplugin \
		-u ${TESTS_INIT} \
		-c "PlenaryBustedDirectory ${TESTS_DIR} { minimal_init = '${TESTS_INIT}' }"
