"""일과 생성(텍스트) 평가 실행: 입력 세트 > Gemini > 카드 JSON 저장 + 자동 지표

사용: python3 run_text.py <variant> [--cases t01,l01] [--category 초단문]
variant 폴더(variants/<이름>/)에 있는 파일이 기본값을 덮어쓴다 (없으면 현재 코드 기본값 = baseline)
  create.txt      일과 생성 시스템 프롬프트
  preprocess.txt  있으면 생성 전에 입력 정리 호출을 한 번 더 한다
  variant.json    {"extra_step_properties": {...}, "use_pictogram_catalog": true}
"""
import argparse
import json
import re
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import lib

RESULT_ROOT = lib.TOOL_DIR / "results"
VARIANT_ROOT = lib.TOOL_DIR / "variants"

# 보호자 문구에 나오면 안 되는 말 (용어 규칙, 진단명 수집 금지)
BANNED_TERMS = ["아이", "아동", "우리 아이", "자폐", "진단", "장애", "발달"]
# 한 문장에 행동을 이어 붙이는 표현
CHAINING_PATTERN = re.compile(r"(고 |하고|해서|한 뒤|하면서|며 |,)")
# 개인정보가 그대로 나오면 안 됨
PERSONAL_TERMS = ["김하늘", "010", "5678"]


def load_variant(name: str) -> dict:
    folder = VARIANT_ROOT / name
    config = {"extra_step_properties": {}, "use_pictogram_catalog": True}
    if (folder / "variant.json").exists():
        config.update(json.loads((folder / "variant.json").read_text(encoding="utf-8")))
    create_file = folder / "create.txt"
    config["create_prompt"] = (
        create_file.read_text(encoding="utf-8") if create_file.exists()
        else lib.baseline_prompt("GEMINI_ROUTINE_CREATE_PREFIX", config.get("defaults_ref"))
    )
    preprocess_file = folder / "preprocess.txt"
    config["preprocess_prompt"] = preprocess_file.read_text(encoding="utf-8") if preprocess_file.exists() else None
    return config


PREPROCESS_SCHEMA = {
    "type": "object",
    "properties": {"routineText": {"type": "string"}},
    "required": ["routineText"],
}


def preprocess(config: dict, case: dict, settings: dict) -> str:
    """입력 정리 호출: 오타, 초단문 보강, 장문 요약 > 정리된 일과 문장"""
    user_content = json.dumps({"routineText": case["text"]}, ensure_ascii=False)
    data, _, _ = lib.call_text_model(config["preprocess_prompt"], user_content, PREPROCESS_SCHEMA, settings)
    return data["routineText"]


def measure(case: dict, result: dict) -> dict:
    """카드 JSON 자동 지표 (사람이 볼 수 있게 위반 목록으로 모은다)"""
    steps = result.get("steps", [])
    violations = []
    if not 1 <= len(steps) <= 10:
        violations.append(f"단계수:{len(steps)}")
    catalog = set(lib.pictogram_ids())
    seen_titles = set()
    for step in steps:
        title, description = step.get("title", ""), step.get("description", "")
        word_count = len(title.split())
        if word_count > 4:
            violations.append(f"제목어절{word_count}:{title}")
        if not title.endswith("요"):
            violations.append(f"제목어미:{title}")
        if not description.endswith("요"):
            violations.append(f"설명어미:{description}")
        if len(description) > 16:
            violations.append(f"설명길이{len(description)}:{description}")
        if CHAINING_PATTERN.search(description) or CHAINING_PATTERN.search(title):
            violations.append(f"행동연결:{title}/{description}")
        if title in seen_titles:
            violations.append(f"제목중복:{title}")
        seen_titles.add(title)
        picto = step.get("pictogramId")
        if picto and picto not in catalog:
            violations.append(f"없는그림:{picto}")
    full_text = json.dumps(result, ensure_ascii=False)
    for term in BANNED_TERMS:
        if term in full_text and term not in case["text"]:
            violations.append(f"금지어:{term}")
    for term in PERSONAL_TERMS:
        if term in full_text:
            violations.append(f"개인정보노출:{term}")
    return {
        "step_count": len(steps),
        "violation_count": len(violations),
        "violations": violations,
        "pictogram_filled": sum(1 for step in steps if step.get("pictogramId")),
    }


def run_case(config: dict, case: dict, settings: dict, out_dir: Path) -> dict:
    record = {"id": case["id"], "category": case["category"], "input": case["text"]}
    try:
        routine_text = case["text"]
        if config["preprocess_prompt"]:
            routine_text = preprocess(config, case, settings)
            record["preprocessed"] = routine_text
        user_content = lib.create_user_content(
            routine_text, case["goals"], case.get("answers", []), config["use_pictogram_catalog"]
        )
        schema = lib.routine_response_schema(config["extra_step_properties"], config.get("description_hint"))
        result, elapsed, usage = lib.call_text_model(config["create_prompt"], user_content, schema, settings)
        record.update(result=result, elapsed_seconds=round(elapsed, 1), usage=usage, metrics=measure(case, result))
    except Exception as error:
        record["error"] = str(error)
    (out_dir / f"{case['id']}.json").write_text(json.dumps(record, ensure_ascii=False, indent=1), encoding="utf-8")
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("variant")
    parser.add_argument("--cases", default="")
    parser.add_argument("--category", default="")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()

    cases = json.loads((lib.TOOL_DIR / "cases.json").read_text(encoding="utf-8"))
    if args.cases:
        wanted = set(args.cases.split(","))
        cases = [case for case in cases if case["id"] in wanted]
    if args.category:
        cases = [case for case in cases if case["category"] == args.category]

    prod = lib.load_prod_config()
    print(lib.describe_prod_config(prod))
    if prod["text"]["provider"] != "GEMINI":
        raise SystemExit("텍스트 제공자 OPENAI 경로는 아직 하네스에 없음: 운영이 OPENAI 이면 먼저 구현한다")
    config = load_variant(args.variant)
    settings = lib.load_gemini_settings()
    settings["text-model"] = prod["text"]["model"]       # 운영 모델 (application-dev.yml 값 대신)
    settings["thinking-budget"] = prod["text"]["thinking_budget"]
    out_dir = RESULT_ROOT / args.variant / "text"
    out_dir.mkdir(parents=True, exist_ok=True)

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        records = list(pool.map(lambda case: run_case(config, case, settings, out_dir), cases))

    failed = [record for record in records if "error" in record]
    done = [record for record in records if "error" not in record]
    violation_total = sum(record["metrics"]["violation_count"] for record in done)
    summary = {
        "variant": args.variant, "case_count": len(records), "failed": [r["id"] for r in failed],
        "violation_total": violation_total,
        "violations_per_case": round(violation_total / max(len(done), 1), 2),
        "avg_step_count": round(sum(r["metrics"]["step_count"] for r in done) / max(len(done), 1), 1),
    }
    (out_dir / "_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))
    for record in failed:
        print("FAIL", record["id"], record["error"][:200], file=sys.stderr)


if __name__ == "__main__":
    main()
