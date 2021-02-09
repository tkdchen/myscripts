#!/usr/bin/env bash

set -ex

# {{{ Packages
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-33.noarch.rpm

declare -a packages
packages=(
python3-devel python3-tabulate
git neovim podman podman-compose buildah rpmdevtools krb5-workstation vagrant
xed kwrite
VirtualBox
)

sudo dnf install -y "${packages[@]}"
# }}}

# {{{ Container images
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

# vim: foldmethod=marker ts=4 sw=4 autoindent
