#!/bin/sh

PHOTO_DIR="$HOME/Pictures/BingWallpaper"
BING_URL="https://www.bing.com"
IMAGE_ENDPOINT="{$BING_URL}/HPImageArchive.aspx"

curl --silent -G -d format=js -d idx=0 -d n=2 -d mkt=zh-CN "$IMAGE_ENDPOINT" | \
jq '.images[].url'
