
OS := $(shell uname)
NEOVIM_CONFIG_DIR=$(HOME)/.config/nvim

ifeq ($(OS),Darwin)
	opt=-B
else
	opt=-S
endif
INSTALL=install -m 664 -b $(opt) "$(date +'-%Y%m%d-%H%M%S')"

.PHONY: install-bashrc
install-bashrc:
	@$(INSTALL) config-files/bashrc.common $(HOME)/.bashrc.common
	@if [ "$(OS)" == "Darwin" ]; then \
		$(INSTALL) config-files/bashrc.macos $(HOME)/.bash_profile; \
	else \
		$(INSTALL) config-files/bashrc $(HOME)/.bashrc; \
	fi

.PHONY: install-nvim-init
install-nvim-init:
	@[ -e "$(NEOVIM_CONFIG_DIR)" ] || mkdir -p "$(NEOVIM_CONFIG_DIR)"
	@$(INSTALL) config-files/nvim-init.vim $(NEOVIM_CONFIG_DIR)/init.vim

.PHONY: install-vimrc
install-vimrc:
	@$(INSTALL) config-files/vimrc $(HOME)/.vimrc

.PHONY: install-config-files
install-config-files: install-bashrc install-nvim-init install-vimrc
