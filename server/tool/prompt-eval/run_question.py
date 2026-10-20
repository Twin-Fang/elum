"""되묻기 질문(추가 질문과 선택지) 평가: 입력 세트 > Gemini > 질문 JSON 저장 + 자동 지표

사용: python3 run_question.py <variant> [--cases t01] [--goals both|items|new]
variants/<이름>/question.txt 가 있으면 질문 지시문을 덮어쓴다 (없으면 현재 코드 기본값)
"""
import argparse
import json
from concurrent.futures import ThreadPoolExecutor

import lib

GOAL_SETS = {"both": ["PREPARE_ITEMS", "PREPARE_NEW"], "items": ["PREPARE_ITEMS"], "new": ["PREPARE_NEW"]}
FORBIDDEN_LABELS = ["직접 입력", "기타", "그 외", "없음", "해당 없음"]


def load_prompt(variant: str) -> str:
    folder = lib.TOOL_DIR / "variants" / variant
    path = folder / "question.txt"
    if path.exists():
        return path.read_text(encoding="utf-8")
    ref = json.loads((folder / "variant.json").read_text(encoding="utf-8")).get("defaults_ref") if (folder / "variant.json").exists() else None
    return lib.baseline_prompt("GEMINI_ROUTINE_QUESTION_PREFIX", ref)


def measure(goals: list, result: dict) -> list:
    violations = []
    questions = result.get("questions", [])
    if len(questions) != len(goals):
        violations.append(f"질문수{len(questions)}")
    for question in questions:
        labels = [option["label"] for option in question["options"]]
        if len(set(labels)) != len(labels):
            violations.append(f"선택지중복:{question['question']}")
        for label in labels:
            if any(word in label for word in FORBIDDEN_LABELS):
                violations.append(f"금지선택지:{label}")
            if len(label) > 10:
                violations.append(f"선택지길이{len(label)}:{label}")
        if len(question["question"]) > 24:
            violations.append(f"질문길이{len(question['question'])}:{question['question']}")
    return violations


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("variant")
    parser.add_argument("--cases", default="")
    parser.add_argument("--goals", default="both")
    args = parser.parse_args()
    goals = GOAL_SETS[args.goals]
    cases = json.loads((lib.TOOL_DIR / "cases.json").read_text(encoding="utf-8"))
    if args.cases:
        cases = [case for case in cases if case["id"] in set(args.cases.split(","))]
    prod = lib.load_prod_config()
    print(lib.describe_prod_config(prod))
    prompt, settings = load_prompt(args.variant), lib.load_gemini_settings()
    settings["text-model"] = prod["text"]["model"]
    settings["thinking-budget"] = prod["text"]["thinking_budget"]
    config_path = lib.TOOL_DIR / "variants" / args.variant / "variant.json"
    hints = json.loads(config_path.read_text(encoding="utf-8")) if config_path.exists() else {}
    out_dir = lib.TOOL_DIR / "results" / args.variant / "question"
    out_dir.mkdir(parents=True, exist_ok=True)

    def run(case):
        try:
            result, _, _ = lib.call_text_model(
                prompt, lib.question_user_content(case["text"], goals), lib.question_response_schema(len(goals), hints), settings)
            record = {"id": case["id"], "input": case["text"], "result": result, "violations": measure(goals, result)}
        except Exception as error:
            record = {"id": case["id"], "input": case["text"], "error": str(error)}
        (out_dir / f"{case['id']}.json").write_text(json.dumps(record, ensure_ascii=False, indent=1), encoding="utf-8")
        return record

    with ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(run, cases))
    for record in records:
        print(f"\n[{record['id']}] {record['input'][:60]}")
        if "error" in record:
            print("  ERROR", record["error"][:120]); continue
        for question in record["result"]["questions"]:
            options = " / ".join(f"{o['emoji']}{o['label']}" for o in question["options"])
            print(f"  {question['supportGoal'][8:]}: {question['question']}  ->  {options}")
        if record["violations"]:
            print("  ⚠", record["violations"])


if __name__ == "__main__":
    main()
