"""카드 이미지 평가 실행: 텍스트 결과의 카드 > Gemini 이미지 > PNG + 케이스별 컨택트 시트

사용: python3 run_image.py <variant> --cases n01,s02 [--text-from baseline] [--max-steps 6]
variant.json 의 image_scene_mode 로 그림 프롬프트에 싣는 장면 정보를 고른다
  description        카드 설명 하나만 (현재 서버 동작)
  title_description  제목 + 설명 + 일과 제목
  scene_field        위 + 글 AI 가 준 imagePromptEn (구체 장면 한 줄)
variant 폴더의 image.txt 가 있으면 그림 지시문을 덮어쓴다.
"""
import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import lib

FONT_PATH = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
TILE_SIZE = (360, 270)
CAPTION_HEIGHT = 56
COLUMN_COUNT = 3


def load_image_config(variant: str) -> dict:
    folder = lib.TOOL_DIR / "variants" / variant
    config = {"image_scene_mode": "description"}
    if (folder / "variant.json").exists():
        config.update(json.loads((folder / "variant.json").read_text(encoding="utf-8")))
    image_file = folder / "image.txt"
    config["image_prefix"] = (
        image_file.read_text(encoding="utf-8") if image_file.exists()
        else lib.baseline_prompt("GEMINI_ROUTINE_IMAGE_PREFIX")
    )
    return config


def build_scene(mode: str, routine_title: str, step: dict) -> dict:
    if mode == "description":
        return {"stepDescription": step["description"]}
    scene = {"routineTitle": routine_title, "stepTitle": step["title"], "stepDescription": step["description"]}
    if mode == "scene_field" and step.get("imagePromptEn"):
        scene["sceneDetail"] = step["imagePromptEn"]
    return scene


def render_step(config: dict, settings: dict, record: dict, step: dict, character: str, out_dir: Path) -> Path:
    path = out_dir / f"{record['id']}_{step['order']:02d}.png"
    prompt = lib.image_prompt(
        config["image_prefix"], build_scene(config["image_scene_mode"], record["result"]["title"], step), character
    )
    try:
        png, _ = lib.call_image_model(prompt, character, settings)
        path.write_bytes(png)
    except Exception as error:
        path.with_suffix(".err.txt").write_text(str(error), encoding="utf-8")
    return path


def contact_sheet(record: dict, steps: list, paths: list, character: str, out_path: Path):
    font = ImageFont.truetype(FONT_PATH, 16)
    rows = (len(steps) + COLUMN_COUNT - 1) // COLUMN_COUNT
    tile_height = TILE_SIZE[1] + CAPTION_HEIGHT
    sheet = Image.new("RGB", (COLUMN_COUNT * TILE_SIZE[0], rows * tile_height + 30), "white")
    draw = ImageDraw.Draw(sheet)
    draw.text((6, 5), f"[{record['id']}] {record['input'][:40]} / {character}", fill="black", font=font)
    for index, (step, path) in enumerate(zip(steps, paths)):
        x, y = (index % COLUMN_COUNT) * TILE_SIZE[0], (index // COLUMN_COUNT) * tile_height + 30
        if path.exists():
            tile = Image.open(path).convert("RGB")
            tile.thumbnail(TILE_SIZE)
            sheet.paste(tile, (x, y))
        else:
            draw.text((x + 10, y + 100), "이미지 실패", fill="red", font=font)
        draw.text((x + 4, y + TILE_SIZE[1] + 2), f"{step['order']}. {step['title']}", fill="black", font=font)
        draw.text((x + 4, y + TILE_SIZE[1] + 26), step["description"], fill="#555555", font=font)
        draw.rectangle([x, y, x + TILE_SIZE[0] - 1, y + tile_height - 1], outline="#dddddd")
    sheet.save(out_path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("variant")
    parser.add_argument("--cases", required=True)
    parser.add_argument("--text-from", default="")
    parser.add_argument("--max-steps", type=int, default=6)
    parser.add_argument("--workers", type=int, default=3)
    args = parser.parse_args()

    text_variant = args.text_from or args.variant
    config = load_image_config(args.variant)
    settings = lib.load_gemini_settings()
    out_dir = lib.TOOL_DIR / "results" / args.variant / "images"
    out_dir.mkdir(parents=True, exist_ok=True)

    for index, case_id in enumerate(args.cases.split(",")):
        record = json.loads((lib.TOOL_DIR / "results" / text_variant / "text" / f"{case_id}.json").read_text(encoding="utf-8"))
        # 케이스마다 캐릭터를 하나로 고정한다 (카드 간 일관성 확인)
        character = ["LULU", "POPO"][index % 2]
        steps = record["result"]["steps"][: args.max_steps]
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            paths = list(pool.map(lambda step: render_step(config, settings, record, step, character, out_dir), steps))
        contact_sheet(record, steps, paths, character, out_dir / f"sheet_{case_id}.png")
        print("sheet", out_dir / f"sheet_{case_id}.png")


if __name__ == "__main__":
    main()
