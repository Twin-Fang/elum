"""행동카드 평가 실행: 보호자 입력 세트 > Haiku 5.5(claude -p) > 채점 > 보고서

사용: python3 run_cards.py [--variant 이름] [--effort low] [--cases a01,b02] [--style 두서없음] [--repeat 3] [--yes]
변형: variants/cards/<이름>.txt 는 운영 지시문 뒤에 덧붙임, <이름>.full.txt 는 지시문 전체 교체
--yes 없으면 호출 수·추정 비용만 보여 주고 멈춘다. 운영 설정·지시문은 바꾸지 않는다.
"""
import argparse
import json
import re
import sys
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor

import card_report
import card_request
import card_rules
import lib

RESULT_ROOT = lib.TOOL_DIR / "results" / "cards"
VARIANT_FOLDER = lib.TOOL_DIR / "variants" / "cards"
# 호출당 추정 비용 (캐시 쓰기 포함 소액, 첫 실행 뒤 실측으로 대체)
ESTIMATED_COST_PER_CALL_USD = 0.004
PROVIDER_SETTING_KEYS = ["TEXT_PROVIDER_SELECTED", "CLAUDE_TEXT_MODEL", "CLAUDE_TEXT_EFFORT",
                         "IMAGE_PROVIDER_SELECTED", "OPENAI_IMAGE_MODEL", "OPENAI_IMAGE_QUALITY"]


# 예시 칩 원본: 서버 문구 파일 (사본을 두지 않음, #1226)
CHIP_CASE_FILE = "chips"
CHIP_PHRASES_FILE = lib.RESOURCES_DIR / "i18n" / "routine-phrases_ko.properties"
CHIP_EXAMPLE_PATTERN = re.compile(r"^suggestion\.(\d+)\.example=(.*)$")
CHIP_TEXT_PATTERN = re.compile(r"^suggestion\.(\d+)\.text=(.*)$")


def load_chip_cases() -> list:
    """routine-phrases_ko.properties 예시 칩 > 입력 세트 (카드 0장이면 실패)"""
    text_by_number, example_by_number = {}, {}
    for line in CHIP_PHRASES_FILE.read_text(encoding="utf-8").splitlines():
        if match := CHIP_TEXT_PATTERN.match(line):
            text_by_number[match[1]] = match[2]
        elif match := CHIP_EXAMPLE_PATTERN.match(line):
            example_by_number[match[1]] = match[2]
    return [{"id": f"chip{number}", "demand": text_by_number.get(number, ""), "style": "예시칩",
             "text": example, "goals": [], "must": [], "must_not": [], "order": [], "max_steps": 10}
            for number, example in sorted(example_by_number.items())]


def select_cases(args) -> list:
    """입력 세트 고르기 (id, 입력 방식, 요구 종류)"""
    if args.case_file == CHIP_CASE_FILE:
        cases = load_chip_cases()
    else:
        cases = json.loads((lib.TOOL_DIR / args.case_file).read_text(encoding="utf-8"))
    if args.cases:
        wanted = set(args.cases.split(","))
        cases = [case for case in cases if case["id"] in wanted]
    if args.style:
        cases = [case for case in cases if case["style"] == args.style]
    if args.demand:
        cases = [case for case in cases if case["demand"] == args.demand]
    return cases


def run_one(case: dict, repeat_index: int, system_prompt: str, schema: dict, out_dir, effort: str) -> dict:
    """입력 1건 호출 > 채점 > 파일 저장 (실패해도 기록)"""
    record = {"id": case["id"], "demand": case["demand"], "style": case["style"], "input": case["text"],
              "repeat": repeat_index}
    try:
        user_content = lib.create_user_content(case["text"], case.get("goals", []), case.get("answers", []))
        response = card_request.call_claude_for_card(system_prompt, schema, user_content, effort)
        record.update(response)
        record["grade"] = card_rules.grade_card(case, response["card"])
    except Exception as error:
        record["error"] = str(error)
        record["grade"] = {"verdict": "error", "issues": [{"level": "fail", "code": "호출실패", "detail": str(error)[:200]}]}
    file_name = f"{case['id']}_{repeat_index}.json"
    (out_dir / file_name).write_text(json.dumps(record, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{case['id']}#{repeat_index} {record['grade']['verdict']}", flush=True)
    return record


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--variant", default="prod", help="variants/cards/<이름>.txt 를 운영 지시문 뒤에 덧붙여 시험")
    parser.add_argument("--effort", default=card_request.TEXT_EFFORT)
    parser.add_argument("--case-file", default="card_cases.json", help="입력 세트 (처음 보는 입력: card_cases_holdout.json, 예시 칩: chips)")
    parser.add_argument("--cases", default="")
    parser.add_argument("--style", default="")
    parser.add_argument("--demand", default="")
    parser.add_argument("--repeat", type=int, default=1, help="입력당 호출 수 (결과 흔들림 확인)")
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--resume", default="", help="이 실행 폴더 이름에서 이어서: 저장된 호출은 건너뜀 (중단 대비)")
    parser.add_argument("--yes", action="store_true")
    args = parser.parse_args()

    cases = select_cases(args)
    call_count = len(cases) * args.repeat
    session = card_request.AdminSession()
    settings = session.read_settings(PROVIDER_SETTING_KEYS)
    production_prompt = session.read_prompt("GEMINI_ROUTINE_CREATE_PREFIX")
    print(f"[운영 값] {json.dumps(settings, ensure_ascii=False)}")
    print(f"[조건] 모델 {card_request.TEXT_MODEL}/{card_request.TEXT_EFFORT}, 지시문 운영 DB {len(production_prompt)}자, "
          f"변형 {args.variant}, 스키마·보강 {card_request.JAVA_REF}")
    print(f"[계획] 입력 {len(cases)}건 x {args.repeat} = {call_count}회, 추정 ${call_count * ESTIMATED_COST_PER_CALL_USD:.2f}")
    if not args.yes:
        print("--yes 를 붙이면 실행")
        return

    full_file = VARIANT_FOLDER / f"{args.variant}.full.txt"
    if full_file.exists():
        system_prompt = card_request.build_replaced_system_prompt(full_file.read_text(encoding="utf-8"))
    else:
        variant_text = ""
        if args.variant != "prod":
            variant_text = (VARIANT_FOLDER / f"{args.variant}.txt").read_text(encoding="utf-8")
        system_prompt = card_request.build_system_prompt(production_prompt, variant_text)
    schema = card_request.build_routine_schema()

    run_name = args.resume or time.strftime("%Y%m%d_%H%M%S")
    set_suffix = "__holdout" if "holdout" in args.case_file else ""
    out_dir = RESULT_ROOT / f"{args.variant}__{args.effort}{set_suffix}" / run_name
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "_system_prompt.txt").write_text(system_prompt, encoding="utf-8")

    # 호출마다 파일로 저장하므로 중단돼도 남은 호출만 다시 돈다
    jobs = [(case, index) for case in cases for index in range(args.repeat)
            if not (out_dir / f"{case['id']}_{index}.json").exists()]
    print(f"[이어서] 남은 호출 {len(jobs)}회", flush=True)
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        list(pool.map(lambda job: run_one(job[0], job[1], system_prompt, schema, out_dir, args.effort), jobs))
    records = card_report.load_records(out_dir)

    summary = card_report.write_report(records, out_dir, args.variant, settings)
    print(json.dumps(summary, ensure_ascii=False))
    print(f"보고서: {out_dir / 'report.md'}")
    if Counter(record["grade"]["verdict"] for record in records)["error"]:
        print("호출 실패 건 있음", file=sys.stderr)


if __name__ == "__main__":
    main()
