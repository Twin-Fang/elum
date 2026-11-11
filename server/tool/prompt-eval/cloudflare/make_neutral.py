"""#1257 성별 중립 생김새 후보 3개 x 약점 카드 8장 (klein-4b 512x376) > v1 과 나란히"""
import concurrent.futures
import json

from PIL import Image, ImageDraw, ImageFont

import make_images as m
import make_sizes as sizes

STYLE = sizes.PROMPT_HEAD.split(" Only one character:")[0]
CANDIDATES = {
    "n1_messy_green": "a simple cartoon child with a round head, short messy black hair, dot eyes, rosy cheeks, a plain green t-shirt and light blue long pants",
    "n2_bowl_orange": "a simple cartoon child with a round head, short black bowl-cut hair, dot eyes, rosy cheeks, a plain orange hoodie and gray long pants",
    "n3_neutral_mint": "a gender-neutral simple cartoon child with a round head, short black hair, dot eyes, rosy cheeks, a plain mint t-shirt and navy long pants",
}


def draw(name, case_id, step, seed, env):
    width, height = 512, 376
    scene = step["imagePromptEn"].replace("The character", "The child").replace("the character", "the child")
    prompt = f"{STYLE} Only one character: {CANDIDATES[name]}. {scene}"
    base = f"https://api.cloudflare.com/client/v4/accounts/{env['CLOUDFLARE_ACCOUNT_ID']}/ai/run/@cf/black-forest-labs"
    body, content_type = m.multipart({"prompt": prompt, "width": width, "height": height, "seed": seed}, {})
    out_path = m.IMAGE_DIR / f"{case_id}_{step['order']:02d}_{name}.png"
    try:
        data = m.post(f"{base}/flux-2-klein-4b", env["CLOUDFLARE_API_TOKEN"], body, content_type)
        out_path.write_bytes(__import__("base64").b64decode(data["result"]["image"]))
        return out_path
    except Exception as error:
        print(name, case_id, step["order"], (error.read().decode() if hasattr(error, "read") else str(error))[:200])
        return None


env = m.load_env()
texts = json.loads((m.OUT_DIR / "texts.json").read_text(encoding="utf-8"))
seeds = {case_id: 1000 + number for number, case_id in enumerate(texts)}
steps = {(c, s["order"]): s for c, item in texts.items() for s in item["routine"]["steps"]}
rows = {"v1_bob_yellow": {k: m.IMAGE_DIR / f"{k[0]}_{k[1]:02d}_size_512x376.png" for k in sizes.TARGETS}}
with concurrent.futures.ThreadPoolExecutor(3) as pool:
    for name in CANDIDATES:
        futures = {pool.submit(draw, name, c, steps[(c, o)], seeds[c], env): (c, o) for c, o in sizes.TARGETS}
        rows[name] = {futures[f]: f.result() for f in concurrent.futures.as_completed(futures)}

font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 18)
cell_w, cell_h, head_h, label_w = 330, 243, 46, 170
sheet = Image.new("RGB", (label_w + cell_w * len(sizes.TARGETS), head_h + cell_h * len(rows)), "white")
d = ImageDraw.Draw(sheet)
for col, key in enumerate(sizes.TARGETS):
    d.text((label_w + col * cell_w + 8, 12), f"{key[0]} {key[1]}. {steps[key]['title']}", fill="black", font=font)
for row, (label, paths) in enumerate(rows.items()):
    top = head_h + row * cell_h
    d.text((8, top + cell_h // 2 - 10), label, fill="black", font=font)
    for col, key in enumerate(sizes.TARGETS):
        if paths.get(key):
            sheet.paste(sizes.fit(Image.open(paths[key]).convert("RGB"), cell_w, cell_h), (label_w + col * cell_w, top))
sheet.save(m.OUT_DIR / "sheet_neutral.png")
print("failures:", sum(1 for r in rows.values() for p in r.values() if p is None))
