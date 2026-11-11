"""행동카드 보고서: 요약 숫자 + 문제 큰 순으로 입력·카드·그림 가이드를 나란히 + 두 실행 비교

비교: python3 card_report.py <기준 폴더> <변형 폴더>
재채점(호출 없음): python3 card_report.py --regrade <폴더>
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

import card_rules

VERDICT_ORDER = {"error": 0, "fail": 1, "warn": 2, "pass": 3}
INPUT_PREVIEW_LENGTH = 400


def summarize(records: list) -> dict:
    """판정 수, 문제 종류, 장수, 입력 방식별 실패, 흔들림, 비용"""
    verdicts = Counter(record["grade"]["verdict"] for record in records)
    codes = Counter(issue["code"] for record in records for issue in record["grade"]["issues"])
    step_counts = [len(record["card"].get("steps") or []) for record in records if "card" in record]
    fail_by_style, total_by_style = Counter(), Counter()
    for record in records:
        total_by_style[record["style"]] += 1
        if record["grade"]["verdict"] in ("fail", "error"):
            fail_by_style[record["style"]] += 1
    return {
        "calls": len(records),
        "verdicts": dict(verdicts),
        "pass_rate_without_fail": round(1 - (verdicts["fail"] + verdicts["error"]) / max(len(records), 1), 3),
        "steps_average": round(sum(step_counts) / max(len(step_counts), 1), 1),
        "steps_max": max(step_counts, default=0),
        "steps_over_7": sum(1 for count in step_counts if count > 7),
        "cost_usd": round(sum(record.get("cost_usd", 0) for record in records), 4),
        "issue_codes": dict(codes.most_common()),
        "fail_by_style": {style: f"{fail_by_style[style]}/{total}" for style, total in total_by_style.items()},
    }


def find_unstable_cases(records: list) -> dict:
    """반복 호출에서 장수 차이나 판정이 갈린 입력"""
    grouped = defaultdict(list)
    for record in records:
        grouped[record["id"]].append(record)
    unstable = {}
    for case_id, runs in grouped.items():
        if len(runs) < 2:
            continue
        counts = [len(run.get("card", {}).get("steps") or []) for run in runs]
        verdicts = {run["grade"]["verdict"] for run in runs}
        if max(counts) - min(counts) >= 2 or len(verdicts) > 1:
            unstable[case_id] = {"steps": counts, "verdicts": sorted(verdicts)}
    return unstable


def render_record(record: dict) -> list:
    """입력 1건: 입력, 카드 표, 문제"""
    text = record["input"]
    preview = text if len(text) <= INPUT_PREVIEW_LENGTH else text[:INPUT_PREVIEW_LENGTH] + "…"
    lines = [f"### {record['id']} [{record['grade']['verdict']}] {record['demand']} / {record['style']}", "",
             f"> {preview}", ""]
    card = record.get("card")
    if card:
        lines += [f"**{card.get('title', '')}** ({len(card.get('steps') or [])}장)", "",
                  "| # | 제목 | 읽어 주는 말 | 그림 가이드 |", "|---|---|---|---|"]
        for number, step in enumerate(card.get("steps") or [], 1):
            lines.append(f"| {number} | {step.get('title', '')} | {step.get('description', '')} "
                         f"| {step.get('imagePromptEn', '')} |")
        lines.append("")
    for issue in record["grade"]["issues"]:
        lines.append(f"- {issue['level']} {issue['code']}: {issue['detail']}")
    lines.append("")
    return lines


def write_report(records: list, out_dir: Path, variant: str, settings: dict) -> dict:
    """report.md, _summary.json 저장 > 요약"""
    summary = summarize(records)
    summary["unstable"] = find_unstable_cases(records)
    (out_dir / "_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1), encoding="utf-8")
    lines = [f"# 행동카드 평가: {variant}", "", f"운영 값: `{json.dumps(settings, ensure_ascii=False)}`", "",
             "```json", json.dumps(summary, ensure_ascii=False, indent=1), "```", ""]
    ordered = sorted(records, key=lambda record: (VERDICT_ORDER[record["grade"]["verdict"]], record["id"]))
    for record in ordered:
        lines += render_record(record)
    (out_dir / "report.md").write_text("\n".join(lines), encoding="utf-8")
    return summary


def load_records(folder: Path) -> list:
    return [json.loads(path.read_text(encoding="utf-8")) for path in sorted(folder.glob("*.json"))
            if not path.name.startswith("_")]


def compare_runs(baseline_folder: Path, variant_folder: Path):
    """두 실행 비교: 요약 숫자 + 판정이 바뀐 입력"""
    baseline, variant = load_records(baseline_folder), load_records(variant_folder)
    for name, records in (("기준", baseline), ("변형", variant)):
        summary = summarize(records)
        print(name, {key: summary[key] for key in ("calls", "verdicts", "steps_average", "steps_max", "steps_over_7", "cost_usd")})
        print(" ", summary["issue_codes"])
    baseline_verdicts = {record["id"]: record["grade"]["verdict"] for record in baseline}
    for record in variant:
        before = baseline_verdicts.get(record["id"])
        if before and before != record["grade"]["verdict"]:
            print(f"{record['id']}: {before} > {record['grade']['verdict']}")


def regrade_run(folder: Path):
    """저장한 카드를 지금 채점 규칙·기대값으로 다시 채점 (AI 호출 없음)"""
    cases = {}
    for case_file in Path(__file__).parent.glob("card_cases*.json"):
        cases.update({case["id"]: case for case in json.loads(case_file.read_text(encoding="utf-8"))})
    records = []
    for path in sorted(folder.glob("*.json")):
        if path.name.startswith("_"):
            continue
        record = json.loads(path.read_text(encoding="utf-8"))
        if "card" in record:
            record["grade"] = card_rules.grade_card(cases[record["id"]], record["card"])
            path.write_text(json.dumps(record, ensure_ascii=False, indent=1), encoding="utf-8")
        records.append(record)
    summary = write_report(records, folder, folder.parent.name, {})
    print(json.dumps({key: summary[key] for key in ("calls", "verdicts", "steps_average", "steps_over_7", "issue_codes")}, ensure_ascii=False))


if __name__ == "__main__":
    if sys.argv[1] == "--regrade":
        regrade_run(Path(sys.argv[2]))
    else:
        compare_runs(Path(sys.argv[1]), Path(sys.argv[2]))
