"""카드 그림 자동 지표: 배경이 흰색인가(네 모서리), 검은 덩어리가 있는가, 실패 파일 수

사용: python3 image_metrics.py <variant> [<variant> ...]
"""
import glob
import json
import sys
from pathlib import Path

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


YELLOW_CAST_MIN = 20        # (R+G)/2 - B 가 이 값 넘으면 노란 기 (루루 원색 #EFEDE8 은 5 안팎)
LIGHT_PIXEL_MIN = 200       # 털 색 후보: 밝지만 순백이 아닌 픽셀


def yellow_cast_share(path: str) -> float:
    """밝은 비백색 픽셀 중 노란 기가 도는 비율 (루루 털색이 크림 노랑으로 번졌는지)"""
    pixels = Image.open(path).convert("RGB").resize((200, 150)).get_flattened_data()
    light = [(r, g, b) for r, g, b in pixels if min(r, g, b) >= LIGHT_PIXEL_MIN and not (r > 250 and g > 250 and b > 250)]
    if not light:
        return 0.0
    return sum(1 for r, g, b in light if (r + g) / 2 - b > YELLOW_CAST_MIN) / len(light)


def main():
    for variant in sys.argv[1:]:
        folder = lib.TOOL_DIR / "results" / variant / "images"
        paths = sorted(p for p in glob.glob(str(folder / "*_[0-9][0-9].png")))
        failed = len(glob.glob(str(folder / "*.err.txt")))
        results = [measure(path) for path in paths]
        total = max(len(results), 1)
        white = sum(1 for r in results if r["is_white_background"])
        dark = sum(1 for r in results if r["has_dark_block"])
        meta_file = folder / "meta.json"
        if meta_file.exists():
            meta = json.loads(meta_file.read_text(encoding="utf-8"))
            lulu = [yellow_cast_share(p) for p in paths if meta.get(Path(p).name.split("_")[0]) == "LULU"]
            if lulu:
                print(f"  루루 {len(lulu)}장: 노란 기 평균 {sum(lulu) / len(lulu):.2f}, 0.5 초과 {sum(1 for v in lulu if v > 0.5)}장")
        print(f"{variant}: 그림 {len(results)}장, 흰 배경 {white}장 ({white * 100 // total}%), 검은 덩어리 {dark}장, 생성 실패 {failed}장")


if __name__ == "__main__":
    main()
