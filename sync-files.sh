#!/usr/bin/env bash

set -ex

src_host=$1
src_home=$2

dirs=(Documents Music Pictures Videos books certificates irclogs .ssh)

for src_dir in "${dirs[@]}"; do
  rsync -arv ${src_host}:${src_home}/${src_dir} $HOME
done

# TODO: sync up other necessary configuration files

rsync -av ${src_host}:${src_home}/.pypirc $HOME
rsync -av ${src_host}:${src_home}/.config/pip/pip.conf $HOME/.config/pip/pip.conf
