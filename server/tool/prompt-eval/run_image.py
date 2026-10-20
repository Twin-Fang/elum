"""카드 이미지 평가 실행: 텍스트 결과의 카드 > 운영과 같은 그림 제공자 > PNG + 케이스별 컨택트 시트

사용: python3 run_image.py <variant> --cases n01,s02 [--text-from before] [--max-steps 5] [--max-images 40] [--yes]
- 그림 제공자, 모델, 품질, 지시문 언어는 prod-config.json (운영 서버 설정)을 따른다. 시작 전에 장수와 추정 비용을 보여 주고
  --yes 가 없으면 멈춘다. --max-images 를 넘는 요청은 거절한다 (돈이 나가는 호출이라서)
- variant.json
    image_scene_mode   description(변경 전 서버 동작) | scene_field (제목 + 설명 + 일과 제목 + 영어 장면)
    image_layout       true 면 코드의 화면 규격(ImageCardLayoutRules)을 지시문 뒤에 붙인다
    defaults_ref       코드 기본값을 읽을 git ref (예: origin/develop = 변경 전)
- variants/<이름>/image.txt 가 있으면 그림 지시문(DB 값 대신)을 덮어쓴다. 운영 DB 값은 prod-prompts/image_ko.txt 에 둔다.
"""
import argparse
import json
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import lib

FONT_PATH = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
TILE_SIZE = (360, 270)
CAPTION_HEIGHT = 56
COLUMN_COUNT = 3
DEFAULT_MAX_IMAGES = 40


def load_image_config(variant: str, prod: dict) -> dict:
    folder = lib.TOOL_DIR / "variants" / variant
    config = {"image_scene_mode": "description", "image_layout": False, "defaults_ref": None}
    if (folder / "variant.json").exists():
        config.update(json.loads((folder / "variant.json").read_text(encoding="utf-8")))
    language = prod["image"]["prompt_language"]
    prefix_key = "GEMINI_ROUTINE_IMAGE_PREFIX" if language == "KO" else "ROUTINE_IMAGE_PREFIX_EN"
    prompts_dir = prod["prompts"]["dir"]
    override = folder / "image.txt"
    prod_file = lib.TOOL_DIR / prompts_dir / f"image_{language.lower()}.txt" if prompts_dir else None
    if override.exists():
        prefix = override.read_text(encoding="utf-8")
    elif prod_file is not None and prod_file.exists():
        prefix = prod_file.read_text(encoding="utf-8")
    else:
        prefix = lib.baseline_prompt(prefix_key, config["defaults_ref"])
    if config["image_layout"]:
        prefix = prefix + "\n\n" + lib.layout_rules(language)
    config["image_prefix"] = prefix
    config["language"] = language
    return config


def build_scene(mode: str, routine_title: str, step: dict) -> dict:
    if mode == "description":
        return {"stepDescription": step["description"]}
    scene = {"routineTitle": routine_title, "stepTitle": step["title"], "stepDescription": step["description"]}
    if mode == "scene_field" and step.get("imagePromptEn"):
        scene["sceneDetail"] = step["imagePromptEn"]
    return scene


def render_step(config: dict, prod: dict, settings: dict, record: dict, step: dict, character: str, out_dir: Path) -> Path:
    path = out_dir / f"{record['id']}_{step['order']:02d}.png"
    provider = prod["image"]["provider"]
    # OpenAI 는 참조 이미지를 못 받는다: 프롬프트에도 사실대로 적는다 (서버 OpenAiImageClient 동일)
    prompt = lib.image_prompt(
        config["image_prefix"], build_scene(config["image_scene_mode"], record["result"]["title"], step), character,
        reference_provided=(provider == "GEMINI"), language=config["language"],
    )
    try:
        if provider == "OPENAI":
            png, _ = lib.call_openai_image(prompt, prod)
        else:
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
            tile = Image.open(path)
            if tile.mode in ("RGBA", "LA"):
                backdrop = Image.new("RGB", tile.size, "white")
                backdrop.paste(tile, mask=tile.getchannel("A"))
                tile = backdrop
            tile = tile.convert("RGB")
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
    parser.add_argument("--max-steps", type=int, default=5)
    parser.add_argument("--max-images", type=int, default=DEFAULT_MAX_IMAGES)
    parser.add_argument("--workers", type=int, default=3)
    parser.add_argument("--yes", action="store_true", help="추정 비용을 확인하고 실행")
    args = parser.parse_args()

    prod = lib.load_prod_config()
    print(lib.describe_prod_config(prod))
    config = load_image_config(args.variant, prod)
    case_ids = args.cases.split(",")
    records = {
        case_id: json.loads(
            (lib.TOOL_DIR / "results" / (args.text_from or args.variant) / "text" / f"{case_id}.json").read_text(encoding="utf-8"))
        for case_id in case_ids
    }
    image_count = sum(min(len(record["result"]["steps"]), args.max_steps) for record in records.values())
    cost = image_count * lib.COST_PER_IMAGE_USD[prod["image"]["provider"]]
    print(f"그림 {image_count}장, 추정 ${cost:.2f} (약 {int(cost * 1400):,}원, 서버 단가 기준 추정)")
    if image_count > args.max_images:
        sys.exit(f"--max-images {args.max_images} 초과: 케이스나 --max-steps 를 줄이거나 한도를 올린다")
    if not args.yes:
        sys.exit("확인 후 --yes 를 붙여 실행")

    settings = lib.load_gemini_settings() if prod["image"]["provider"] == "GEMINI" else {}
    out_dir = lib.TOOL_DIR / "results" / args.variant / "images"
    out_dir.mkdir(parents=True, exist_ok=True)

    for index, case_id in enumerate(case_ids):
        record = records[case_id]
        # 케이스마다 캐릭터를 하나로 고정한다 (카드 간 일관성 확인)
        character = ["LULU", "POPO"][index % 2]
        steps = record["result"]["steps"][: args.max_steps]
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            paths = list(pool.map(lambda step: render_step(config, prod, settings, record, step, character, out_dir), steps))
        contact_sheet(record, steps, paths, character, out_dir / f"sheet_{case_id}.png")
        print("sheet", out_dir / f"sheet_{case_id}.png")
        # 크레딧 소진이면 남은 케이스를 헛돌리지 않고 멈춘다
        errors = " ".join(path.read_text(encoding="utf-8") for path in out_dir.glob(f"{case_id}_*.err.txt"))
        if "depleted" in errors or "insufficient_quota" in errors or "billing" in errors.lower():
            print("크레딧 소진 또는 결제 오류: 중단")
            break


if __name__ == "__main__":
    main()
