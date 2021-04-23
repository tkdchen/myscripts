#!/usr/bin/env bash

set -ex

# {{{ Packages
echo "📦 Install packages"

version_id=$(cat /etc/os-release | grep "^VERSION_ID" | cut -d'=' -f2)
sudo dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${version_id}.noarch.rpm

declare -a packages
packages=(
    emacs hexchat
    gcc gcc-c++ golang npm
    python3-devel python3-pip python3-tabulate
    krb5-devel
    git neovim podman podman-compose buildah rpmdevtools krb5-workstation vagrant rsync
    xed kwrite kate
    VirtualBox
    vim-enhanced
    ibus ibus-table ibus-table-chinese ibus-table-code ibus-pinyin
	gnome-tweaks terminator
)

sudo dnf install -y ${packages[@]}
# }}}

# {{{ Container images
echo "🏗️ Pull container images"
declare -a images
images=(
    registry.fedoraproject.org/fedora:32
    registry.fedoraproject.org/fedora:33
    registry.fedoraproject.org/fedora:rawhide
    centos:7
    centos:8
)

for image in "${images[@]}"; do
    podman pull "$image"
done
# }}}

code_dir="$HOME/code"
[ -e "$code_dir" ] || mkdir "$code_dir"

vagrant_machines="$HOME/vagrant-machines"
[ -e "$vagrant_machines" ] || mkdir "$vagrant_machines"

# {{{ Gitconfig
echo "Configure git"
git config --global alias.br branch
git config --global alias.st status
git config --global alias.cm commit
git config --global alias.co checkout
git config --global color.diff true
git config --global color.status true
git config --global color.branch true
git config --global color.ui true
git config --global user.name "Chenxiong Qi"
git config --global user.email "qcxhome@gmail.com"
git config --global core.editor vim
# }}}

# {{{ Install LSP servers
echo "✍️ Install LSP servers"

lsp_servers=(
	pyright
    bash-language-server
    dockerfile-language-server-nodejs
    typescript-language-server
)
home_npm="$HOME/npm"
[ -e "$home_npm" ] || mkdir "$home_npm"
(cd ${home_npm}; for lsp_s in "${lsp_servers[@]}"; do
    npm i $lsp_s
done)
# }}}

# vim: foldmethod=marker ts=4 sw=4 autoindent
