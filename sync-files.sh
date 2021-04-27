#!/usr/bin/env bash

set -ex

src_host=$1
remote_user=${2:-$USER}
src_home="/home/${remote_user}"
src_root="${remote_user}@${src_host}:${src_home}"
src_config_dir="${src_root}/.config"

personal_data() {
dirs=(Documents Music Pictures Videos books certificates irclogs)

for src_dir in "${dirs[@]}"; do
  rsync -arv ${src_root}/${src_dir} $HOME
done
}

# TODO: sync up other necessary configuration files

sync_config_files() {
rsync -av ${src_root}/.ssh/config $HOME/.ssh/
rsync -av ${src_root}/.pypirc $HOME
rsync -av ${src_root}/.emacs $HOME

config_dir="$HOME/.config"
pip_config_dir="${config_dir}/pip"
[ -e "$pip_config_dir" ] || mkdir "$pip_config_dir"
rsync -av ${src_config_dir}/pip/pip.conf "${pip_config_dir}/pip.conf"

rsync -arv ${src_config_dir}/jenkins "$config_dir"
rsync -arv ${src_config_dir}/jenkins_jobs "$config_dir"
}

#personal_data
sync_config_files
