#!/usr/bin/env python3
"""
Download YOLOv5-face model from GitHub release
"""
import urllib.request
import sys

def download_file(url, output_path):
    """Download file from URL with progress"""
    print(f"Downloading from: {url}")
    print(f"Saving to: {output_path}")

    try:
        # Add headers to avoid being blocked
        headers = {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
        }
        req = urllib.request.Request(url, headers=headers)

        with urllib.request.urlopen(req) as response:
            total_size = int(response.headers.get('content-length', 0))
            print(f"Total size: {total_size / (1024*1024):.2f} MB")

            with open(output_path, 'wb') as f:
                downloaded = 0
                block_size = 8192
                while True:
                    buffer = response.read(block_size)
                    if not buffer:
                        break
                    downloaded += len(buffer)
                    f.write(buffer)
                    if total_size > 0:
                        percent = int(50 * downloaded / total_size)
                        sys.stdout.write(f"\r[{'=' * percent}{' ' * (50-percent)}] {downloaded / (1024*1024):.2f} MB")
                        sys.stdout.flush()
            print("\nDownload complete!")
            return True
    except Exception as e:
        print(f"\nError downloading: {e}")
        return False

if __name__ == "__main__":
    # Try multiple URLs for YOLOv5-face model
    urls = [
        "https://github.com/deepcam-cn/yolov5-face/releases/download/v0.0.0/yolov5n-0.5.pt",
        "https://github.com/hpc203/yolov5-face-landmarks-opencv-v2/raw/main/weights/yolov5n-face.onnx",
    ]

    output_file = "yolov5n-face.onnx"

    for url in urls:
        print(f"\nTrying URL: {url}")
        if download_file(url, output_file):
            import os
            size = os.path.getsize(output_file)
            if size > 100000:  # At least 100KB for a valid model
                print(f"Successfully downloaded model ({size / (1024*1024):.2f} MB)")
                sys.exit(0)
            else:
                print(f"Downloaded file too small ({size} bytes), trying next URL...")
                os.remove(output_file)

    print("\nFailed to download from all sources")
    sys.exit(1)
