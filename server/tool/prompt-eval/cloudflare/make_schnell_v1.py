"""#1257 schnell 4 steps 를 만화 아이 v1 프롬프트로: 약점 카드 8장 > klein-4b 512x376 과 나란히"""
import base64
import concurrent.futures
import json

from PIL import Image, ImageDraw, ImageFont

import make_images as m
import make_sizes as sizes

TARGETS = sizes.TARGETS


def draw_schnell(case_id, step, env):
    scene = step["imagePromptEn"].replace("The character", "The child").replace("the character", "the child")
    base = f"https://api.cloudflare.com/client/v4/accounts/{env['CLOUDFLARE_ACCOUNT_ID']}/ai/run/@cf/black-forest-labs"
    out_path = m.IMAGE_DIR / f"{case_id}_{step['order']:02d}_schnell_v1.png"
    try:
        data = m.post(f"{base}/flux-1-schnell", env["CLOUDFLARE_API_TOKEN"],
                      json.dumps({"prompt": sizes.PROMPT_HEAD + scene, "steps": 4}).encode(), "application/json")
        out_path.write_bytes(base64.b64decode(data["result"]["image"]))
        return out_path
    except Exception as error:
        print(case_id, step["order"], (error.read().decode() if hasattr(error, "read") else str(error))[:200])
        return None


env = m.load_env()
texts = json.loads((m.OUT_DIR / "texts.json").read_text(encoding="utf-8"))
steps = {(c, s["order"]): s for c, item in texts.items() for s in item["routine"]["steps"]}
with concurrent.futures.ThreadPoolExecutor(3) as pool:
    futures = {pool.submit(draw_schnell, c, steps[(c, o)], env): (c, o) for c, o in TARGETS}
    schnell_paths = {futures[f]: f.result() for f in concurrent.futures.as_completed(futures)}

# 시트: 행 = schnell v1 / klein-4b 512x376
rows = {"schnell 4step v1": schnell_paths,
        "klein-4b 512x376": {k: m.IMAGE_DIR / f"{k[0]}_{k[1]:02d}_size_512x376.png" for k in TARGETS}}
font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 18)
cell_w, cell_h, head_h, label_w = 330, 243, 46, 170
sheet = Image.new("RGB", (label_w + cell_w * len(TARGETS), head_h + cell_h * len(rows)), "white")
draw = ImageDraw.Draw(sheet)
for col, key in enumerate(TARGETS):
    draw.text((label_w + col * cell_w + 8, 12), f"{key[0]} {key[1]}. {steps[key]['title']}", fill="black", font=font)
for row, (label, paths) in enumerate(rows.items()):
    top = head_h + row * cell_h
    draw.text((8, top + cell_h // 2 - 10), label, fill="black", font=font)
    for col, key in enumerate(TARGETS):
        if paths.get(key):
            sheet.paste(sizes.fit(Image.open(paths[key]).convert("RGB"), cell_w, cell_h), (label_w + col * cell_w, top))
        else:
            draw.text((label_w + col * cell_w + 10, top + 100), "실패", fill="red", font=font)
sheet.save(m.OUT_DIR / "sheet_schnell_v1.png")
print("failures:", sum(1 for p in schnell_paths.values() if p is None))
