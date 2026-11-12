"""5차: v1 프롬프트 x 크기 3개 x 카드 8장 > 크기별 품질 (작을수록 512 타일 적음 = 싸다)
시트 2장: 전체 비교(sheet_sizes.png), 앱 카드 칸 실제 픽셀(940x690)로 늘린 확대 비교(sheet_sizes_zoom.png)
"""
import concurrent.futures
import json

from PIL import Image, ImageDraw, ImageFont

import make_images as m

PROMPT_HEAD = ("Flat vector illustration, simple picture-book style, thick dark brown outlines, flat soft pastel "
               "colors, plain light cream background, no shading. Wordless image, no letters anywhere. "
               "Only one character: a simple cartoon child with a round head, a short black bob haircut, dot eyes, "
               "rosy cheeks, a plain yellow t-shirt and light blue long pants. ")
# 크기 이름 > (가로, 세로): 카드 칸 비율 1.36 근처, 512 타일 4 / 2 / 1
SIZES = {"1024x752": (1024, 752), "696x512": (696, 512), "512x376": (512, 376)}
TARGETS = [("n02", 1), ("n02", 3), ("n02", 4), ("o05", 1), ("o05", 5), ("o05", 7), ("n06", 4), ("n06", 5)]
# 앱 카드 그림 칸 실제 픽셀 (313x230dp x 3배 밀도 근처)
CARD_PIXEL_WIDTH, CARD_PIXEL_HEIGHT = 940, 690


def render_sized(size_name, case_id, seed, step, env):
    """크기만 바꿔 klein-4b 호출 (make_images.render 의 크기 상수를 호출마다 넘길 수 없어 직접 조립)"""
    width, height = SIZES[size_name]
    base = f"https://api.cloudflare.com/client/v4/accounts/{env['CLOUDFLARE_ACCOUNT_ID']}/ai/run/@cf/black-forest-labs"
    scene = step["imagePromptEn"].replace("The character", "The child").replace("the character", "the child")
    body, content_type = m.multipart({"prompt": PROMPT_HEAD + scene, "width": width, "height": height, "seed": seed}, {})
    out_path = m.IMAGE_DIR / f"{case_id}_{step['order']:02d}_size_{size_name}.png"
    try:
        data = m.post(f"{base}/flux-2-klein-4b", env["CLOUDFLARE_API_TOKEN"], body, content_type)
        out_path.write_bytes(__import__("base64").b64decode(data["result"]["image"]))
        return out_path
    except Exception as error:
        print(size_name, case_id, step["order"], (error.read().decode() if hasattr(error, "read") else str(error))[:200])
        return None


def fit(image, width, height):
    """가운데 채우기 (앱 카드 칸과 같은 방식)"""
    ratio = max(width / image.width, height / image.height)
    image = image.resize((int(image.width * ratio), int(image.height * ratio)), Image.LANCZOS)
    left, top = (image.width - width) // 2, (image.height - height) // 2
    return image.crop((left, top, left + width, top + height))


def main():
    env = m.load_env()
    texts = json.loads((m.OUT_DIR / "texts.json").read_text(encoding="utf-8"))
    seeds = {case_id: 1000 + number for number, case_id in enumerate(texts)}
    steps = {(c, s["order"]): s for c, item in texts.items() for s in item["routine"]["steps"]}
    paths = {}
    with concurrent.futures.ThreadPoolExecutor(3) as pool:
        futures = {pool.submit(render_sized, size, c, seeds[c], steps[(c, o)], env): (size, c, o)
                   for size in SIZES for c, o in TARGETS}
        for future in concurrent.futures.as_completed(futures):
            paths[futures[future]] = future.result()
    font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 18)

    # 전체 비교: 행 = 크기, 열 = 카드
    cell_w, cell_h, head_h, label_w = 330, 243, 46, 120
    sheet = Image.new("RGB", (label_w + cell_w * len(TARGETS), head_h + cell_h * len(SIZES)), "white")
    draw = ImageDraw.Draw(sheet)
    for col, (c, o) in enumerate(TARGETS):
        draw.text((label_w + col * cell_w + 8, 12), f"{c} {o}. {steps[(c, o)]['title']}", fill="black", font=font)
    for row, size in enumerate(SIZES):
        top = head_h + row * cell_h
        draw.text((8, top + cell_h // 2 - 10), size, fill="black", font=font)
        for col, key in enumerate(TARGETS):
            path = paths[(size, *key)]
            if path:
                sheet.paste(fit(Image.open(path).convert("RGB"), cell_w, cell_h), (label_w + col * cell_w, top))
    sheet.save(m.OUT_DIR / "sheet_sizes.png")

    # 확대 비교: 카드 2장을 앱 실제 픽셀 크기로 (흐림 확인용)
    zoom_targets = [("n02", 3), ("n06", 5)]
    zoom = Image.new("RGB", (CARD_PIXEL_WIDTH * len(SIZES), (CARD_PIXEL_HEIGHT + 40) * len(zoom_targets)), "white")
    draw = ImageDraw.Draw(zoom)
    for row, key in enumerate(zoom_targets):
        for col, size in enumerate(SIZES):
            top = row * (CARD_PIXEL_HEIGHT + 40)
            draw.text((col * CARD_PIXEL_WIDTH + 10, top + 8), f"{size} > {CARD_PIXEL_WIDTH}x{CARD_PIXEL_HEIGHT}", fill="black", font=font)
            path = paths[(size, *key)]
            if path:
                zoom.paste(fit(Image.open(path).convert("RGB"), CARD_PIXEL_WIDTH, CARD_PIXEL_HEIGHT), (col * CARD_PIXEL_WIDTH, top + 40))
    zoom.save(m.OUT_DIR / "sheet_sizes_zoom.png")
    print("done, failures:", sum(1 for p in paths.values() if p is None))


if __name__ == "__main__":
    main()
