
run-regular-tasks: bing cleanup-old-bing-wallpapers download-bing-wallpapers

bing:
	@cd bing; go build bing.go
.PHONY: bing

download-bing-wallpapers:
	@cd bing; ./bing ; ./bing ; ./bing ; ./bing ; ./bing ; ./bing : ./bing
.PHONY: download-bing-wallpapers

cleanup-old-bing-wallpapers:
	@find ~/Pictures/BingWallpaper -mtime +30 -exec rm '{}' +
.PHONY: cleanup-old-bing-wallpapers
