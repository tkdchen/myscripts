import argparse
import logging
import json
import os

from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Final
from urllib.parse import parse_qs, urljoin, urlparse

import urllib3

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger("bing")

PHOTO_DIR: Final[str] = os.path.expanduser("~/Pictures/BingWallpaper")
BING_URL: Final[str] = "https://www.bing.com"
IMAGE_ENDPOINT: Final[str] = f"{BING_URL}/HPImageArchive.aspx"


def parse_cli() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--download-dir",
        metavar="PATH",
        default=PHOTO_DIR,
        help=(
            "A relative or absolute path to a directory holding the "
            "downloaded images. Default: %(default)s."
        ),
    )
    parser.add_argument(
        "--market",
        default="zh-CN",
        help="The market code, e.g. en-US or zh-CN. Default: %(default)s.",
    )
    parser.add_argument(
        "--resolution",
        default="1920x1080",
        help="The image resolution. Default: %(default)s.",
    )
    parser.add_argument(
        "--count",
        default=5,
        type=int,
        help="The number of images to be downloaded. Default: %(default)s.",
    )

    return parser.parse_args()


def download_image(http_pool: urllib3.PoolManager, image_url: str, download_dir: Path) -> None:
    qs_args = parse_qs(urlparse(image_url).query)
    full_image_file = download_dir.joinpath(qs_args["id"][0])

    if full_image_file.exists():
        logger.debug("Image exists: %s", str(full_image_file))
        return

    resp = http_pool.request("GET", urljoin(IMAGE_ENDPOINT, image_url))
    if resp.status == 200:
        full_image_file.write_bytes(resp.data)
        logger.info("✅ Downloaded %s", full_image_file)
    else:
        logger.warning(
            "Cannot fetch image from Bing: %s", resp.data.decode("utf-8")
        )
 

def main():
    args = parse_cli()

    download_dir = Path(args.download_dir)
    if not download_dir.exists():
        download_dir.mkdir(parents=True)

    http_pool = urllib3.PoolManager(num_pools=5)

    data = {
        "format": "js",
        "idx": "0",
        "n": str(args.count),
        "mkt": args.market,
    }
    resp = http_pool.request("GET", IMAGE_ENDPOINT, fields=data)
    if resp.status == 200:
        daily_images_info = json.loads(resp.data.decode("utf-8"))
    else:
        logger.warning("Bing responds: %s", resp.data.decode("utf-8"))
        return

    executor = ThreadPoolExecutor(max_workers=5)
    futures = [
        executor.submit(download_image, http_pool, image_info["url"], download_dir)
        for image_info in daily_images_info["images"]
    ]
    for future in futures:
        future.result()


if __name__ == "__main__":
    main()
