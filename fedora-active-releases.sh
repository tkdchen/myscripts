#!/usr/bin/env bash

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "${0} [fedora|epel]"
    exit 0
fi

if [ -n "$1" ]; then
    short_name="short=$1"
else
    short_name=""
fi

curl -s "https://pdc.fedoraproject.org/rest_api/v1/product-versions/?active=true&${short_name}" | \
jq '.results[].version' | \
tr -d '"'