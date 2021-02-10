#!/usr/bin/env bash

set -ex

images_url=http://mirrors.aliyun.com/fedora/development/rawhide/Cloud/x86_64/images/
# Example image filename: Fedora-Cloud-Base-Vagrant-Rawhide-20210114.n.1.x86_64.vagrant-virtualbox.box
image_filename=$(
    curl -L "$images_url" |
    grep "Fedora-Cloud-Base-Vagrant-Rawhide-[0-9]\+.n.[0-9]\+.x86_64.vagrant-virtualbox.box" |
    cut -d'"' -f2
)
if [ -z "$image_filename" ]; then
    echo "Cannot find out the Rawhide image file name." >&2
    exit 1
fi
box_name="fedora/rawhide-cloud-base"
vagrant box remove -f $box_name || :
vagrant box add --name $box_name "${images_url}${image_filename}"

image="registry.fedoraproject.org/fedora:rawhide"
podman rmi "$image"
podman pull "$image"
