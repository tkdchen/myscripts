
run-regular-tasks: bing cleanup-old-bing-wallpapers download-bing-wallpapers onedrive-sync

bing:
	@cd bing; go build bing.go
.PHONY: bing

download-bing-wallpapers:
	@cd bing; ./bing ; ./bing ; ./bing ; ./bing ; ./bing ; ./bing : ./bing
.PHONY: download-bing-wallpapers

cleanup-old-bing-wallpapers:
	@find ~/Pictures/BingWallpaper -mtime +30 -exec rm '{}' +
.PHONY: cleanup-old-bing-wallpapers

onedrive-sync:
	@onedrive --synchronize --verbose
.PHONY: onedrive-sync
