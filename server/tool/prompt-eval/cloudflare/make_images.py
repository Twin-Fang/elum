"""#1257 카드 그림 생성: texts.json > Cloudflare Workers AI (무료 한도) > images/ + 컨택트 시트
변형 3개: schnell(4 steps, 1024 정사각) / klein-4b + 루루 참조 그림(1152x848) / klein-4b 참조 없음(n02 만)
프롬프트는 운영 FluxPromptBuilder 와 같은 모양: 화풍 지시문 + Only one character: 생김새. + 장면 한 줄
"""
import base64
import concurrent.futures
import json
import os
import time
import urllib.request
import uuid
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT_DIR = Path(__file__).resolve().parent.parent / "results/cloudflare"
IMAGE_DIR = OUT_DIR / "images"
ENV_FILE = Path("/Users/suhsaechan/Desktop/Programming/project/elum_codegate2026/server/tool/prompt-eval/.env.local")
LULU_PNG = Path("/Users/suhsaechan/Desktop/Programming/project/elum_codegate2026/server/src/main/resources/static/characters/lulu.png")

# PromptDefaults.FLUX_ROUTINE_IMAGE_PREFIX 사본
FLUX_PREFIX = ("Flat vector illustration, simple picture-book style, thick dark brown outlines, flat soft pastel "
               "colors, plain light cream background, no shading. Wordless image, no letters anywhere.")
# CharacterType.LULU.appearanceEn 사본
LULU_APPEARANCE = ("a round baby kitten with plain pale gray-ivory fur (a soft light gray with only a faint warm tone, "
                   "never yellow or cream-yellow), chubby body as big as its head, very short legs, "
                   "triangle ears with light pink insides, tiny round black dot eyes, a tiny pink triangle nose, "
                   "a tiny small mouth, no whiskers, long thin tail stretched to the side")
# 운영 카드 그림 크기 (FluxImageClient IMAGE_WIDTH x IMAGE_HEIGHT)
CARD_WIDTH, CARD_HEIGHT = 1152, 848
VARIANTS = {
    "schnell": {"label": "schnell 4step (1024 정사각)", "cases": None},
    "klein_ref": {"label": "klein-4b + 루루 참조", "cases": None},
    "klein_noref": {"label": "klein-4b 참조 없음", "cases": ["n02"]},
}
WORKER_COUNT = 3


def load_env() -> dict:
    return dict(line.split("=", 1) for line in ENV_FILE.read_text().splitlines() if "=" in line)


def build_prompt(scene: str) -> str:
    """FluxPromptBuilder.build 와 같은 조립 (The character > The kitten)"""
    scene = scene.replace("The character", "The kitten").replace("the character", "the kitten")
    return f"{FLUX_PREFIX} Only one character: {LULU_APPEARANCE}. {scene}"


def post(url: str, token: str, body: bytes, content_type: str) -> dict:
    request = urllib.request.Request(url, data=body, method="POST",
                                     headers={"Authorization": f"Bearer {token}", "Content-Type": content_type})
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read())


def multipart(fields: dict, files: dict) -> tuple:
    """klein-4b 용 multipart 본문 조립 (fields: 글, files: 이름 > 바이트)"""
    boundary = uuid.uuid4().hex
    parts = []
    for name, value in fields.items():
        parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode())
    for name, data in files.items():
        parts.append(f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"; filename=\"{name}.png\"\r\n"
                     f"Content-Type: image/png\r\n\r\n".encode() + data + b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), f"multipart/form-data; boundary={boundary}"


def render(variant: str, case_id: str, seed: int, step: dict, env: dict) -> dict:
    """카드 1장 생성 > 파일 저장 > 소요 시간·실패 사유 반환"""
    base = f"https://api.cloudflare.com/client/v4/accounts/{env['CLOUDFLARE_ACCOUNT_ID']}/ai/run/@cf/black-forest-labs"
    prompt = build_prompt(step["imagePromptEn"])
    out_path = IMAGE_DIR / f"{case_id}_{step['order']:02d}_{variant}.png"
    started = time.time()
    try:
        if variant == "schnell":
            data = post(f"{base}/flux-1-schnell", env["CLOUDFLARE_API_TOKEN"],
                        json.dumps({"prompt": prompt, "steps": 4}).encode(), "application/json")
        else:
            files = {"input_image_0": LULU_PNG.read_bytes()} if variant == "klein_ref" else {}
            body, content_type = multipart(
                {"prompt": prompt, "width": CARD_WIDTH, "height": CARD_HEIGHT, "seed": seed}, files)
            data = post(f"{base}/flux-2-klein-4b", env["CLOUDFLARE_API_TOKEN"], body, content_type)
        image_bytes = base64.b64decode(data["result"]["image"])
        out_path.write_bytes(image_bytes)
        return {"file": out_path.name, "seconds": round(time.time() - started, 1), "error": None}
    except Exception as error:  # 실패도 기록 (한도 초과 4006 등)
        detail = error.read().decode()[:300] if hasattr(error, "read") else str(error)[:300]
        return {"file": None, "seconds": round(time.time() - started, 1), "error": detail}


def contact_sheet(case_id: str, routine: dict, records: dict):
    """일과 1건: 행 = 변형, 열 = 카드. 칸 330x243 (카드 칸 비율)"""
    cell_width, cell_height, label_height, row_label_width = 330, 243, 46, 170
    steps = routine["steps"]
    variants = [v for v in VARIANTS if (VARIANTS[v]["cases"] is None or case_id in VARIANTS[v]["cases"])]
    sheet = Image.new("RGB", (row_label_width + cell_width * len(steps), label_height + cell_height * len(variants)), "white")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 18)
    for column, step in enumerate(steps):
        draw.text((row_label_width + column * cell_width + 8, 12), f"{step['order']}. {step['title']}", fill="black", font=font)
    for row, variant in enumerate(variants):
        top = label_height + row * cell_height
        draw.text((8, top + cell_height // 2 - 10), VARIANTS[variant]["label"], fill="black", font=font)
        for column, step in enumerate(steps):
            record = records.get((case_id, step["order"], variant))
            left = row_label_width + column * cell_width
            if record and record["file"]:
                image = Image.open(IMAGE_DIR / record["file"]).convert("RGB")
                # 앱 카드 칸처럼 가운데 채우기 (313x230 비율)
                ratio = max(cell_width / image.width, cell_height / image.height)
                image = image.resize((int(image.width * ratio), int(image.height * ratio)))
                offset_x, offset_y = (image.width - cell_width) // 2, (image.height - cell_height) // 2
                sheet.paste(image.crop((offset_x, offset_y, offset_x + cell_width, offset_y + cell_height)), (left, top))
            else:
                draw.text((left + 10, top + 100), "실패", fill="red", font=font)
            draw.rectangle((left, top, left + cell_width - 1, top + cell_height - 1), outline="#cccccc")
    sheet.save(OUT_DIR / f"sheet_{case_id}.png")


def main():
    env = load_env()
    IMAGE_DIR.mkdir(exist_ok=True)
    texts = json.loads((OUT_DIR / "texts.json").read_text(encoding="utf-8"))
    jobs = []
    for case_number, (case_id, item) in enumerate(texts.items()):
        seed = 1000 + case_number  # 일과마다 고정 seed (운영과 같은 규칙)
        for step in item["routine"]["steps"]:
            for variant, spec in VARIANTS.items():
                if spec["cases"] is None or case_id in spec["cases"]:
                    jobs.append((variant, case_id, seed, step))
    print(f"[image] {len(jobs)} images")
    records = {}
    with concurrent.futures.ThreadPoolExecutor(WORKER_COUNT) as pool:
        futures = {pool.submit(render, variant, case_id, seed, step, env): (case_id, step["order"], variant)
                   for variant, case_id, seed, step in jobs}
        for future in concurrent.futures.as_completed(futures):
            key = futures[future]
            records[key] = future.result()
            print(f"[image] {key} {records[key]['seconds']}s {records[key]['error'] or 'ok'}")
    (OUT_DIR / "records.json").write_text(
        json.dumps([{"case": k[0], "order": k[1], "variant": k[2], **v} for k, v in records.items()], ensure_ascii=False, indent=1))
    for case_id, item in texts.items():
        contact_sheet(case_id, item["routine"], records)


if __name__ == "__main__":
    main()
