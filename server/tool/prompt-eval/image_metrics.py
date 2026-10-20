"""카드 그림 자동 지표: 배경이 흰색인가(네 모서리), 검은 덩어리가 있는가, 실패 파일 수

사용: python3 image_metrics.py <variant> [<variant> ...]
"""
import glob
import sys

from PIL import Image

import lib

CORNER_SIZE = 12
WHITE_THRESHOLD = 225       # 모서리 평균이 이 값 이상이면 눈으로 흰 배경 (미세한 회색 그늘 허용)
DARK_PIXEL_LEVEL = 25       # 이 밝기 미만은 검은 픽셀
DARK_RATIO_LIMIT = 0.08     # 검은 픽셀이 8% 넘으면 검은 덩어리


def measure(path: str) -> dict:
    image = Image.open(path).convert("RGB")
    width, height = image.size
    corners = [(0, 0), (width - CORNER_SIZE, 0), (0, height - CORNER_SIZE), (width - CORNER_SIZE, height - CORNER_SIZE)]
    corner_means = []
    for x, y in corners:
        pixels = list(image.crop((x, y, x + CORNER_SIZE, y + CORNER_SIZE)).get_flattened_data())
        corner_means.append(sum(sum(pixel) / 3 for pixel in pixels) / len(pixels))
    gray = image.convert("L")
    dark_ratio = sum(1 for value in gray.get_flattened_data() if value < DARK_PIXEL_LEVEL) / (width * height)
    return {"is_white_background": min(corner_means) >= WHITE_THRESHOLD, "has_dark_block": dark_ratio > DARK_RATIO_LIMIT}


def main():
    for variant in sys.argv[1:]:
        folder = lib.TOOL_DIR / "results" / variant / "images"
        paths = sorted(p for p in glob.glob(str(folder / "*_[0-9][0-9].png")))
        failed = len(glob.glob(str(folder / "*.err.txt")))
        results = [measure(path) for path in paths]
        total = max(len(results), 1)
        white = sum(1 for r in results if r["is_white_background"])
        dark = sum(1 for r in results if r["has_dark_block"])
        print(f"{variant}: 그림 {len(results)}장, 흰 배경 {white}장 ({white * 100 // total}%), 검은 덩어리 {dark}장, 생성 실패 {failed}장")


if __name__ == "__main__":
    main()
