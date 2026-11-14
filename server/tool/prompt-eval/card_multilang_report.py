"""다국어 행동카드 비교표: 실행 폴더 여러 개 > 언어 x 변형 표 + 나쁜 출력 목록 (#1375, AI 호출 없음)

사용: python3 card_multilang_report.py <실행 폴더> [<실행 폴더> ...] [--out 파일.md]
지표: 언어 일치(카드 전체, 글 단위), 규칙 위반, 빈 카드, 안전 위반, 평균 토큰(입력·출력), 지시문 글자 수
"""
import argparse
import json
from collections import defaultdict
from pathlib import Path

import card_language
import card_report

LANGUAGE_ORDER = ["ko", "ja", "zh", "es"]
# 언어 일치는 따로 세므로 규칙 위반에서 뺀다
LANGUAGE_CODES = {"언어불일치", "번체"}
# lang 없는 옛 입력(holdout 등): 이 입력 방식이면 '나오면안됨'도 안전 위반으로 센다
SAFETY_STYLES = {"위험요청", "민감", "안전", "개인정보", "지시문삽입"}
OLD_SET_SAFETY_CODES = card_language.ALWAYS_SAFETY_CODES | {"개인정보노출"}


def fill_language_grade(record: dict) -> dict:
    """옛 채점(card_rules) 기록에 다국어 지표 기본값을 채움: 언어 일치는 ko 판정, 안전은 코드로 셈"""
    grade = record["grade"]
    if "language_fields" in grade or "card" not in record:
        return record
    _, matched_count, text_count = card_language.grade_language_match(record["card"], "ko")
    codes = OLD_SET_SAFETY_CODES | ({"나오면안됨"} if record.get("style") in SAFETY_STYLES else set())
    grade.update({
        "language_match": matched_count == text_count,
        "language_fields": [matched_count, text_count],
        "is_zero_card": not (record["card"].get("steps") or []),
        "safety_violations": sum(1 for issue in grade["issues"] if issue["code"] in codes),
    })
    return record


def variant_label(folder: Path) -> str:
    return folder.parent.name.split("__")[0]


def summarize_group(records: list) -> dict:
    """한 언어 x 한 변형 묶음 > 지표"""
    graded = [record for record in records if "card" in record]
    calls = len(graded)
    rule_fail_calls = sum(1 for record in graded if any(
        issue["level"] == "fail" and issue["code"] not in LANGUAGE_CODES for issue in record["grade"]["issues"]))
    warn_issues = sum(1 for record in graded for issue in record["grade"]["issues"]
                      if issue["level"] == "warn" and issue["code"] not in LANGUAGE_CODES)
    matched_fields = sum(record["grade"]["language_fields"][0] for record in graded)
    total_fields = sum(record["grade"]["language_fields"][1] for record in graded)
    wrong_zero = sum(1 for record in graded if record["grade"]["is_zero_card"]
                     and any(issue["code"] == "카드없음" for issue in record["grade"]["issues"]))
    usage = [record.get("usage") or {} for record in graded]
    return {
        "calls": calls,
        "errors": len(records) - calls,
        "language_match_percent": round(100 * sum(record["grade"]["language_match"] for record in graded) / max(calls, 1)),
        "field_match_percent": round(100 * matched_fields / max(total_fields, 1)),
        "rule_fail_calls": rule_fail_calls,
        "warn_issues_per_call": round(warn_issues / max(calls, 1), 2),
        "zero_card_wrong": wrong_zero,
        "zero_card_total": sum(record["grade"]["is_zero_card"] for record in graded),
        "safety_violations": sum(record["grade"]["safety_violations"] for record in graded),
        "input_tokens_average": round(sum(entry.get("input_tokens", 0) for entry in usage) / max(calls, 1)),
        "output_tokens_average": round(sum(entry.get("output_tokens", 0) for entry in usage) / max(calls, 1)),
        "system_prompt_chars": max((record.get("system_prompt_chars", 0) for record in graded), default=0),
        "cost_usd": round(sum(record.get("cost_usd", 0) for record in graded), 3),
    }


def is_bad_record(record: dict) -> bool:
    """보고할 출력: 호출 실패, 언어 불일치, 안전 위반, 잘못 빈 카드, 규칙 fail"""
    if "card" not in record:
        return True
    grade = record["grade"]
    return (not grade["language_match"] or grade["safety_violations"] > 0
            or any(issue["level"] == "fail" for issue in grade["issues"]))


def describe_record(record: dict) -> str:
    """나쁜 출력 한 줄: id, 문제 코드, 카드 제목들"""
    if "card" not in record:
        return f"- `{record['id']}#{record['repeat']}` 호출 실패: {record.get('error', '')[:120]}"
    codes = sorted({f"{issue['code']}({issue['detail'][:40]})" for issue in record["grade"]["issues"]
                    if issue["level"] == "fail"})
    card = record["card"]
    step_titles = " / ".join(step.get("title", "") for step in card.get("steps") or []) or "(빈 카드)"
    return f"- `{record['id']}#{record['repeat']}` {'; '.join(codes)} :: **{card.get('title', '')}** — {step_titles}"


def build_report(folders: list) -> str:
    rows, bad_lines = [], []
    header = ("| 언어 | 변형 | 호출 | 언어일치 카드% | 글단위% | 규칙fail 호출 | 경고/호출 | 잘못 빈 카드 | 빈 카드 전체 "
              "| 안전위반 | 입력토큰 평균 | 출력토큰 평균 | 지시문 글자 | 비용$ |")
    divider = "|" + "---|" * 14
    grouped = defaultdict(list)
    for folder in folders:
        for record in map(fill_language_grade, card_report.load_records(folder)):
            grouped[(record.get("lang", "ko"), variant_label(folder))].append(record)
    for language in LANGUAGE_ORDER:
        for folder in folders:
            label = variant_label(folder)
            records = grouped.get((language, label))
            if not records:
                continue
            summary = summarize_group(records)
            rows.append(f"| {language} | {label} | {summary['calls']}+{summary['errors']}err "
                        f"| {summary['language_match_percent']} | {summary['field_match_percent']} "
                        f"| {summary['rule_fail_calls']} | {summary['warn_issues_per_call']} "
                        f"| {summary['zero_card_wrong']} | {summary['zero_card_total']} | {summary['safety_violations']} "
                        f"| {summary['input_tokens_average']} | {summary['output_tokens_average']} "
                        f"| {summary['system_prompt_chars']} | {summary['cost_usd']} |")
            bad = [record for record in sorted(records, key=lambda entry: (entry["id"], entry["repeat"]))
                   if is_bad_record(record)]
            if bad:
                bad_lines += [f"", f"### {language} / {label} ({len(bad)}건)"] + [describe_record(entry) for entry in bad]
    return "\n".join(["# 다국어 행동카드 비교", "", header, divider] + rows + ["", "## 나쁜 출력"] + bad_lines) + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folders", nargs="+")
    parser.add_argument("--out", default="")
    args = parser.parse_args()
    report = build_report([Path(folder) for folder in args.folders])
    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()
