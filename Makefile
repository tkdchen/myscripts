
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
	@$(INSTALL) dotfiles/bashrc.common $(HOME)/.bashrc.common
	@if [ "$(OS)" == "Darwin" ]; then \
		$(INSTALL) dotfiles/bashrc.macos $(HOME)/.bash_profile; \
	else \
		$(INSTALL) dotfiles/bashrc $(HOME)/.bashrc; \
	fi

.PHONY: install-nvim-init
install-nvim-init:
	@[ -e "$(NEOVIM_CONFIG_DIR)" ] || mkdir -p "$(NEOVIM_CONFIG_DIR)"
	@$(INSTALL) dotfiles/nvim-init.vim $(NEOVIM_CONFIG_DIR)/init.vim

.PHONY: install-vimrc
install-vimrc:
	@$(INSTALL) dotfiles/vimrc $(HOME)/.vimrc

.PHONY: install-config-files
install-config-files: install-bashrc install-nvim-init install-vimrc
