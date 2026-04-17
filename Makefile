DEPS_DIR := deps
MINI_DIR := $(DEPS_DIR)/mini.nvim

.PHONY: install clean test test_file

test: install 
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run()"

test_file: install
	nvim --headless --noplugin -u ./scripts/minimal_init.lua -c "lua MiniTest.run_file('$(FILE)')"

install: $(MINI_DIR)

$(MINI_DIR):
	mkdir -p $(DEPS_DIR)
	git clone --filter=blob:none https://github.com/nvim-mini/mini.nvim $(MINI_DIR)

clean:
	rm -rf $(DEPS_DIR)
