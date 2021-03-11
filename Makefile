
INSTALL_BIN=install -m 664 -b --suffix="$(date +'-%Y%m%d-%H%M%S')"
NEOVIM_CONFIG_DIR=$(HOME)/.config/nvim

.PHONY: install-bashrc
install-bashrc:
	@$(INSTALL_BIN) config-files/bashrc $(HOME)/.bashrc

.PHONY: install-nvim-init
install-nvim-init:
	@[ -e "$(NEOVIM_CONFIG_DIR)" ] || mkdir -p "$(NEOVIM_CONFIG_DIR)"
	@$(INSTALL_BIN) config-files/nvim-init.vim $(NEOVIM_CONFIG_DIR)/init.vim

.PHONY: install-vimrc
install-vimrc:
	@$(INSTALL_BIN) config-files/vimrc $(HOME)/.vimrc

.PHONY: install-config-files
install-config-files: install-bashrc install-nvim-init install-vimrc

