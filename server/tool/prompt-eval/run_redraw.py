"""카드 그림·다시 그리기 E2E 시험 (#1378): 운영 관리자 시험 엔드포인트로 운영 서버가 운영 설정으로 그림

경로 2개 (운영 IMAGE_PROVIDER_SELECTED=CLOUDFLARE 기준, 2026-11-11 전환):
- cf: 운영 기본 경로. 카드 글(+보호자 요청) > FLUX_IMAGE_PROMPT_TRANSLATE 번역(Gemini 글) > Cloudflare klein-4b
- oa: Cloudflare 실패·한도 소진 시 OpenAI fallback. 캐릭터 없이 ROUTINE_IMAGE_PREFIX_EN + 장면 JSON
관리자 시험은 그림만 그리고 저장하지 않음 (AdminPromptService.test). 지시문은 관리자 화면에서 읽기만 함
"""
import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import card_request
import lib

CASES = json.loads((lib.TOOL_DIR / "redraw_cases.json").read_text(encoding="utf-8"))
OUT_ROOT = lib.TOOL_DIR / "results" / "redraw_e2e"
LANGUAGES = ["ko", "en", "ja", "zh", "es"]
FIRST_DRAW_SCENES = ["brush_teeth", "wash_hands", "raincoat", "pack_bag", "ride_bus", "wipe_table"]
# 샘플 수: 손 씻기 첫 그림, 수도꼭지 요청, 일반 요청 (경로별)
WASH_FIRST_SAMPLES = {"cf": 8, "oa": 10}
FAUCET_SAMPLES = 5
REDRAW_SAMPLES = {"cf": 2, "oa": 3}
# Cloudflare 무료 한도 (하루 10,000 neurons, 1장 104.2) 중 운영 사용자 몫을 남기는 상한
CLOUDFLARE_NEURON_STOP = 8500
WORKER_COUNT = 3
# GuardianImageRequest.NOTE_PREFIX, CardImageGenerator.descriptionWithGuardianRequest 와 같은 모양
NOTE_PREFIX = "Guardian note: "
FONT_BY_SCRIPT = {"cjk": "/System/Library/Fonts/Hiragino Sans GB.ttc", "default": "/System/Library/Fonts/AppleSDGothicNeo.ttc"}


def guardian_request(text: str) -> str:
    return NOTE_PREFIX + re.sub(r"\s+", " ", text).strip()


def build_jobs(variant: str) -> list:
    """시험 목록 (경로·묶음·카드·언어·샘플 번호·요청). 같은 입력은 언제나 같은 job id"""
    jobs = []
    for path in ["cf", "oa"]:
        # 1. 첫 그림 언어별 (보호자가 직접 더한 카드 모양: 설명만)
        for scene in FIRST_DRAW_SCENES:
            for language in LANGUAGES:
                jobs.append({"path": path, "group": "first_lang", "card": scene, "lang": language, "sample": 1})
        # 2. 손 씻기 첫 그림 (oa 는 절반을 일과 만들기 모양: 제목 + 영어 장면)
        for sample in range(1, WASH_FIRST_SAMPLES[path] + 1):
            form = "create" if path == "oa" and sample > WASH_FIRST_SAMPLES[path] // 2 else "direct"
            jobs.append({"path": path, "group": "wash_first", "card": "wash_hands", "lang": "ko", "sample": sample, "form": form})
        # 3. 수도꼭지 요청 + 일반 요청
        redraws = [(CASES["faucet_redraw"], FAUCET_SAMPLES, "wash_redraw")] + [
            (redraw, REDRAW_SAMPLES[path], "redraw") for redraw in CASES["redraws"]]
        for redraw, sample_count, group in redraws:
            for sample in range(1, sample_count + 1):
                jobs.append({"path": path, "group": group, "card": redraw["card"], "lang": redraw["lang"],
                             "sample": sample, "redraw": redraw})
    for job in jobs:
        suffix = job["redraw"]["id"] if job.get("redraw") else job.get("form", "direct")
        job["id"] = f"{variant}_{job['path']}_{job['group']}_{job['card']}_{job['lang']}_{suffix}_{job['sample']}"
        job["variant"] = variant
    return jobs


class Harness:
    """관리자 세션 + 운영 지시문 (변형은 덮어씀) + 번역 캐시"""

    def __init__(self, variant_overrides: dict):
        self.session = card_request.AdminSession()
        self.prompts = {key: self.session.read_prompt(key) for key in
                        ["FLUX_ROUTINE_IMAGE_PREFIX", "FLUX_IMAGE_PROMPT_TRANSLATE", "ROUTINE_IMAGE_PREFIX_EN"]}
        self.prompts.update(variant_overrides.get("prompts", {}))
        self.openai_scene_rule = variant_overrides.get("openai_prefix_append", "")
        self.look_change = variant_overrides.get("look_change")
        # 개선안 2: OpenAI 다시 그리기도 Cloudflare 처럼 요청을 반영한 영어 장면을 stepDescription 으로
        self.openai_redraw_uses_translated_scene = variant_overrides.get("openai_redraw_uses_translated_scene", False)
        self.translation_cache_file = OUT_ROOT / "translations.json"
        self.translations = json.loads(self.translation_cache_file.read_text(encoding="utf-8")) \
            if self.translation_cache_file.exists() else {}
        token_page = self.session._get("/admin/prompts?locale=ko")
        self.csrf = re.search(r'name="_csrf" content="([^"]+)"', token_page).group(1)

    def _post(self, path: str, body: dict, timeout: int = 240, attempts: int = 1) -> dict:
        """관리자 JSON POST. 글 호출(번역·미리보기)만 시간 초과 시 다시 보냄 (그림은 비용이라 1회)"""
        for attempt in range(attempts):
            request = urllib.request.Request(
                card_request.ADMIN_BASE_URL + path, data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
                method="POST", headers={"Content-Type": "application/json", "X-CSRF-TOKEN": self.csrf})
            try:
                return json.loads(self.session.opener.open(request, timeout=timeout).read().decode("utf-8"))
            except TimeoutError:
                if attempt == attempts - 1:
                    raise

    def translate(self, text: str, language: str) -> str:
        """운영 GeminiTextClient.translate 와 같은 호출 (temperature 0 이라 입력당 1회만, 캐시)"""
        prompt = self.prompts["FLUX_IMAGE_PROMPT_TRANSLATE"]
        cache_key = f"{hash_text(prompt)}|{text}"
        if cache_key not in self.translations:
            response = self._post("/admin/prompts/FLUX_IMAGE_PROMPT_TRANSLATE/test",
                                  {"content": prompt, "sampleInput": text, "locale": language}, timeout=60, attempts=3)
            self.translations[cache_key] = response["result"]["imagePromptEn"]
            self.translation_cache_file.write_text(json.dumps(self.translations, ensure_ascii=False, indent=1), encoding="utf-8")
        return self.translations[cache_key]

    def prepare(self, job: dict) -> dict:
        """job > 운영과 같은 요청 본문 (key, body) + 운영 서버 미리보기로 조립 결과 확인"""
        routine_title, step_title, description = CASES["cards"][job["card"]][job["lang"]]
        request_text = guardian_request(job["redraw"]["text"]) if job.get("redraw") else None
        if job["path"] == "cf":
            # 다시 그리기: 설명 + " (요청)" 을 번역. 첫 그림(직접 더한 카드): 설명만 번역
            source = description if request_text is None else f"{description} ({request_text})"
            scene_en = self.translate(source, job["lang"])
            key, body = "FLUX_ROUTINE_IMAGE_PREFIX", {
                "content": self.prompts["FLUX_ROUTINE_IMAGE_PREFIX"], "sampleInput": scene_en, "character": "LULU",
                "locale": job["lang"]}
            extra = {"translate_input": source, "scene_en": scene_en}
            # 개선안: 요청이 옷·머리·안경을 바꾸면 기본 옷·머리 없는 생김새로 (인물 생김새 시험 엔드포인트)
            if self.look_change and request_text and re.search(self.look_change["pattern"], scene_en, re.IGNORECASE):
                key, body = "CARD_IMAGE_SUBJECT_CHILD", {
                    "content": self.look_change["body_only_appearance"], "sampleInput": scene_en, "locale": job["lang"]}
                extra["look_change"] = True
        else:
            prefix = self.prompts["ROUTINE_IMAGE_PREFIX_EN"] + self.openai_scene_rule
            if request_text is not None and self.openai_redraw_uses_translated_scene:
                scene_en = self.translate(f"{description} ({request_text})", job["lang"])
                key, body, extra = "ROUTINE_IMAGE_PREFIX_EN", {"content": prefix, "sampleInput": scene_en,
                                                               "locale": job["lang"]}, {"scene_en": scene_en}
            elif request_text is None and job.get("form", "direct") == "direct":
                # 직접 더한 카드: 설명만 (관리자 시험 조립과 운영이 같음)
                key, body, extra = "ROUTINE_IMAGE_PREFIX_EN", {"content": prefix, "sampleInput": description,
                                                               "locale": job["lang"]}, {}
            else:
                # 제목·영어 장면·보호자 요청은 관리자 시험이 못 실음 > 운영 JSON 을 지시문 끝에 붙임 (뒤에 설명만 든 JSON 이 한 번 더 붙음)
                scene = {"routineTitle": routine_title, "stepTitle": step_title, "stepDescription": description}
                if request_text is None:
                    scene["sceneDetail"] = self.translate(description, job["lang"])
                else:
                    scene["guardianRequest"] = request_text
                production_json = json.dumps({"task": "CREATE_ROUTINE_CARD_IMAGE", "scene": scene},
                                             ensure_ascii=False, separators=(",", ":"))
                key, body = "ROUTINE_IMAGE_PREFIX_EN", {
                    "content": prefix + "\n\nScene info:\n" + production_json, "sampleInput": description, "locale": job["lang"]}
                extra = {"production_json": production_json}
        composed = self._post(f"/admin/prompts/{key}/preview", body, timeout=30, attempts=3)["composedPrompt"]
        return {"key": key, "body": body, "composed_prompt": composed, **extra}

    def draw(self, key: str, body: dict) -> bytes:
        response = self._post(f"/admin/prompts/{key}/test", body)
        return base64.b64decode(response["imageDataUri"].split(",", 1)[1])


def hash_text(text: str) -> str:
    import hashlib
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:10]


def cloudflare_neurons_today() -> float:
    """오늘(UTC) Workers AI neurons 합 (분석 읽기 토큰, 값은 출력하지 않음)"""
    env = card_request.load_env_local()
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    query = ("query($account: String!, $start: Time!, $end: Time!) { viewer { accounts(filter: {accountTag: $account}) "
             "{ aiInferenceAdaptive(limit: 2000, filter: {datetime_geq: $start, datetime_leq: $end}) { neurons } } } }")
    body = json.dumps({"query": query, "variables": {"account": env["CLOUDFLARE_ACCOUNT_ID"],
                                                     "start": f"{today}T00:00:00Z", "end": f"{today}T23:59:59Z"}}).encode()
    request = urllib.request.Request("https://api.cloudflare.com/client/v4/graphql", data=body, method="POST", headers={
        "Authorization": "Bearer " + env["CLOUDFLARE_ANALYTICS_TOKEN"], "Content-Type": "application/json"})
    rows = json.loads(urllib.request.urlopen(request, timeout=60).read())["data"]["viewer"]["accounts"][0]["aiInferenceAdaptive"]
    return sum(row["neurons"] for row in rows)


def seed_check(out_dir: Path):
    """그냥 다시 그리기 재현: 운영처럼 같은 번역(온도 0)·같은 seed 로 Cloudflare 직접 2회 > 픽셀 차이
    관리자 시험은 seed 를 못 넘겨 .env.local Cloudflare 토큰으로 직접 부름 (운영과 같은 계정·모델·크기)
    """
    import hashlib
    import uuid
    from PIL import ImageChops
    harness = Harness({})
    env = card_request.load_env_local()
    # 번역 2회 (캐시 없이) > 같은 문장인가
    lines = [harness._post("/admin/prompts/FLUX_IMAGE_PROMPT_TRANSLATE/test", {
        "content": harness.prompts["FLUX_IMAGE_PROMPT_TRANSLATE"], "sampleInput": "칫솔로 이를 닦아요", "locale": "ko"},
        timeout=60, attempts=3)["result"]["imagePromptEn"] for _ in range(2)]
    print("translations identical:", lines[0] == lines[1], lines)
    prompt = harness._post("/admin/prompts/FLUX_ROUTINE_IMAGE_PREFIX/preview", {
        "content": harness.prompts["FLUX_ROUTINE_IMAGE_PREFIX"], "sampleInput": lines[0], "character": "LULU"},
        timeout=30, attempts=3)["composedPrompt"]
    # FluxSeed.of(profileId|일과 제목) 와 같은 계산 (시험용 열쇠)
    seed = int.from_bytes(hashlib.sha256("seed-check|아침 준비".encode()).digest()[:4], "big") & 0x7fffffff
    paths = []
    for attempt in range(2):
        boundary = uuid.uuid4().hex
        fields = {"prompt": prompt, "width": "512", "height": "376", "seed": str(seed)}
        body = b"".join(f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
                        for name, value in fields.items()) + f"--{boundary}--\r\n".encode()
        request = urllib.request.Request(
            f"https://api.cloudflare.com/client/v4/accounts/{env['CLOUDFLARE_ACCOUNT_ID'].strip()}/ai/run/@cf/black-forest-labs/flux-2-klein-4b",
            data=body, method="POST", headers={"Authorization": "Bearer " + env["CLOUDFLARE_API_TOKEN"].strip(),
                                               "Content-Type": f"multipart/form-data; boundary={boundary}"})
        image = base64.b64decode(json.loads(urllib.request.urlopen(request, timeout=120).read())["result"]["image"])
        paths.append(out_dir / f"seedcheck_{attempt + 1}.jpg")
        paths[-1].write_bytes(image)
    difference = ImageChops.difference(Image.open(paths[0]).convert("RGB"), Image.open(paths[1]).convert("RGB"))
    changed = sum(1 for pixel in difference.getdata() if max(pixel) > 16)
    print(f"seed={seed} changed pixels(>16)={changed} / {difference.width * difference.height}", paths)


def run_job(harness: Harness, job: dict, out_dir: Path) -> dict:
    image_path = out_dir / f"{job['id']}.png"
    record = {**{k: v for k, v in job.items() if k != "redraw"}, "redraw_id": (job.get("redraw") or {}).get("id")}
    try:
        prepared = harness.prepare(job)
        record.update({k: v for k, v in prepared.items() if k != "body"})
        started = time.time()
        image_path.write_bytes(harness.draw(prepared["key"], prepared["body"]))
        record.update({"ok": True, "seconds": round(time.time() - started, 1), "file": str(image_path)})
    except Exception as error:  # 실패도 기록하고 다음 장으로 (원인 문자열만)
        record.update({"ok": False, "error": f"{type(error).__name__}: {str(error)[:200]}"})
    return record


def load_manifest(out_dir: Path) -> dict:
    manifest_file = out_dir / "manifest.jsonl"
    if not manifest_file.exists():
        return {}
    records = (json.loads(line) for line in manifest_file.read_text(encoding="utf-8").splitlines() if line.strip())
    return {record["id"]: record for record in records}


def font_for(text: str, size: int):
    # 한글은 SD 고딕, 그 밖(가나·한자·악센트 라틴)은 Hiragino
    has_korean = re.search(r"[가-힣]", text)
    return ImageFont.truetype(FONT_BY_SCRIPT["default" if has_korean else "cjk"], size)


def make_sheets(out_dir: Path, verdicts: dict):
    """묶음별 컨택트 시트 (타일 아래: job 번호, 카드 언어·설명 또는 요청, 판정)"""
    records = [record for record in load_manifest(out_dir).values()]
    tile_width, tile_height, caption_height, columns = 320, 236, 64, 5
    groups = {}
    for record in records:
        groups.setdefault(f"{record['variant']}_{record['path']}_{record['group']}", []).append(record)
    for name, members in groups.items():
        members.sort(key=lambda record: record["id"])
        rows = (len(members) + columns - 1) // columns
        sheet = Image.new("RGB", (columns * tile_width, rows * (tile_height + caption_height) + 28), "white")
        draw = ImageDraw.Draw(sheet)
        draw.text((6, 4), name, fill="black", font=font_for(name, 18))
        for index, record in enumerate(members):
            x, y = (index % columns) * tile_width, (index // columns) * (tile_height + caption_height) + 28
            if record.get("ok") and Path(record["file"]).exists():
                tile = Image.open(record["file"]).convert("RGB")
                tile.thumbnail((tile_width, tile_height))
                sheet.paste(tile, (x, y))
            else:
                draw.text((x + 8, y + 90), "FAILED " + record.get("error", "")[:40], fill="red", font=font_for("x", 13))
            card = CASES["cards"][record["card"]][record["lang"]][2]
            request = next((r["text"] for r in CASES["redraws"] + [CASES["faucet_redraw"]] if r["id"] == record.get("redraw_id")), "")
            line_one = f"#{index + 1} {record['lang']} {record.get('form', '')} {record.get('redraw_id') or ''}"
            line_two = (request or card)[:30]
            verdict = verdicts.get(record["id"], "")
            draw.text((x + 4, y + tile_height + 2), line_one, fill="black", font=font_for(line_one, 14))
            draw.text((x + 4, y + tile_height + 20), line_two, fill="#444444", font=font_for(line_two, 14))
            draw.text((x + 4, y + tile_height + 40), verdict[:40], fill="#b00020" if verdict and not verdict.startswith("OK") else "#1b7f3b",
                      font=font_for(verdict, 13))
            draw.rectangle([x, y, x + tile_width - 1, y + tile_height + caption_height - 1], outline="#dddddd")
        sheet.save(out_dir / f"sheet_{name}.png")
        print("sheet:", out_dir / f"sheet_{name}.png")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["plan", "run", "sheet", "seedcheck"])
    parser.add_argument("--variant", default="prod", help="prod 또는 variants/redraw/<이름>.json")
    parser.add_argument("--path", choices=["cf", "oa"], help="한 경로만")
    parser.add_argument("--groups", help="쉼표 구분 묶음만 (first_lang,wash_first,wash_redraw,redraw)")
    parser.add_argument("--redraw-ids", help="쉼표 구분 요청 id 만")
    parser.add_argument("--samples", type=int, default=0, help="샘플 번호 N 이하만")
    parser.add_argument("--max-images", type=int, default=0, help="이번 실행 그림 상한 (필수)")
    parser.add_argument("--yes", action="store_true")
    args = parser.parse_args()

    overrides = {} if args.variant == "prod" else json.loads(
        (lib.TOOL_DIR / "variants" / "redraw" / f"{args.variant}.json").read_text(encoding="utf-8"))
    out_dir = OUT_ROOT / args.variant
    out_dir.mkdir(parents=True, exist_ok=True)
    if args.command == "seedcheck":
        if not args.yes:
            sys.exit("Cloudflare 2장 (무료 한도 208 neurons): --yes 로 실행")
        seed_check(out_dir)
        return
    if args.command == "sheet":
        verdict_file = out_dir / "verdicts.json"
        make_sheets(out_dir, json.loads(verdict_file.read_text(encoding="utf-8")) if verdict_file.exists() else {})
        return

    jobs = build_jobs(args.variant)
    if args.path:
        jobs = [job for job in jobs if job["path"] == args.path]
    if args.groups:
        jobs = [job for job in jobs if job["group"] in args.groups.split(",")]
    if args.redraw_ids:
        jobs = [job for job in jobs if (job.get("redraw") or {}).get("id") in args.redraw_ids.split(",")]
    if args.samples:
        jobs = [job for job in jobs if job["sample"] <= args.samples]
    done = load_manifest(out_dir)
    pending = [job for job in jobs if not done.get(job["id"], {}).get("ok")]
    counts = {}
    for job in pending:
        counts[f"{job['path']}/{job['group']}"] = counts.get(f"{job['path']}/{job['group']}", 0) + 1
    print(f"[plan] variant={args.variant} pending images={len(pending)} (done {len(jobs) - len(pending)})", counts)
    if args.command == "plan" or not args.yes:
        print("그림 호출 없이 멈춤 (--yes --max-images N 으로 실행)")
        return
    if args.max_images <= 0 or len(pending) > args.max_images:
        sys.exit(f"상한 초과: pending {len(pending)} > --max-images {args.max_images}")
    if any(job["path"] == "cf" for job in pending):
        neurons = cloudflare_neurons_today()
        expected = neurons + 104.2 * sum(job["path"] == "cf" for job in pending)
        print(f"[cloudflare] today neurons={neurons:.0f}, after run≈{expected:.0f} (stop {CLOUDFLARE_NEURON_STOP})")
        if expected > CLOUDFLARE_NEURON_STOP:
            sys.exit("Cloudflare 무료 한도 보호: 실행 안 함")

    harness = Harness(overrides)
    with open(out_dir / "manifest.jsonl", "a", encoding="utf-8") as manifest, ThreadPoolExecutor(WORKER_COUNT) as pool:
        for record in pool.map(lambda job: run_job(harness, job, out_dir), pending):
            manifest.write(json.dumps(record, ensure_ascii=False) + "\n")
            manifest.flush()
            print(("OK  " if record["ok"] else "FAIL"), record["id"], record.get("error", ""))


if __name__ == "__main__":
    main()
