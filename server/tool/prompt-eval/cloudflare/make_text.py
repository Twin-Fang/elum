"""#1257 카드 글 생성: 운영 지시문(create.txt) + 영어 장면 한 줄 > claude -p (Haiku)
운영 Gemini 대신 Claude 구독으로 같은 입력 모양을 흉내 낸다. 결과: texts.json
"""
import json
import subprocess
import sys
from pathlib import Path

EVAL_DIR = Path("/Users/suhsaechan/Desktop/Programming/project/elum_codegate2026/server/tool/prompt-eval")
sys.path.insert(0, str(EVAL_DIR))
import lib  # noqa: E402

OUT_DIR = Path(__file__).resolve().parent.parent / "results/cloudflare"
CASE_IDS = ["n02", "o05", "n06"]
CLAUDE_MODEL = "claude-haiku-5-5"

# GeminiRoutineSchemas.IMAGE_PROMPT_EN_DESCRIPTION 사본
IMAGE_PROMPT_EN_HINT = (
    "One English sentence (under 25 words) telling the illustrator what to draw. Start with 'The character'. "
    "Show one visible pose and the 1-2 objects held or used, placed where they are "
    "(e.g. 'The character stands at a sink and rubs a bar of soap between both hands.'). "
    "Always include one prop that identifies the activity (stethoscope for a check-up, pill and cup for medicine, "
    "wallet and coins for paying). "
    "Turn invisible actions (rest, wait, meet, arrive) into a visible pose (sits on a bench with hands on knees). "
    "Draw only the character: never other people or animals (grandmother, friend, doctor are shown by objects only). "
    "No background places, weather, traffic. "
    "Describe packaged goods and appliances (milk, medicine, snacks, registers) as plain and unmarked, with nothing printed on them. "
    "Never use words that cause text in the picture: exit, sign, label, menu, clock, title, card, ticket, number."
)


def build_system_prompt() -> str:
    """운영 지시문 + 스키마(Gemini responseSchema 대신 글로 전달)"""
    schema = lib.routine_response_schema(
        extra_step_properties={"imagePromptEn": {"type": "string", "description": IMAGE_PROMPT_EN_HINT}}
    )
    prod_prompt = (EVAL_DIR / "prod-prompts/create.txt").read_text(encoding="utf-8")
    return (
        prod_prompt
        + "\n\n[출력 형식]\n아래 JSON Schema 에 맞는 JSON 객체 하나만 출력합니다. 코드블록·설명 없이 JSON 만.\n"
        + json.dumps(schema, ensure_ascii=False)
    )


def parse_json(raw: str) -> dict:
    """응답에서 첫 { ~ 마지막 } 만 파싱 (코드블록 감싸기 방어)"""
    return json.loads(raw[raw.index("{"): raw.rindex("}") + 1])


def main():
    cases = {c["id"]: c for c in json.loads((EVAL_DIR / "cases.json").read_text(encoding="utf-8"))}
    system_prompt = build_system_prompt()
    results = {}
    for case_id in CASE_IDS:
        case = cases[case_id]
        user_content = lib.create_user_content(case["text"], case["goals"], case.get("answers", []))
        completed = subprocess.run(
            ["claude", "-p", "--model", CLAUDE_MODEL, "--system-prompt", system_prompt, "--output-format", "text"],
            input=user_content, capture_output=True, text=True, cwd=OUT_DIR, timeout=300,
        )
        if completed.returncode != 0:
            print(f"[text] {case_id} failed: {completed.stderr[-300:]}")
            continue
        routine = parse_json(completed.stdout)
        results[case_id] = {"input": case["text"], "routine": routine}
        print(f"[text] {case_id} {routine['title']} : {len(routine['steps'])} steps")
        for step in routine["steps"]:
            print(f"   {step['order']}. {step['title']} | {step['imagePromptEn']}")
    (OUT_DIR / "texts.json").write_text(json.dumps(results, ensure_ascii=False, indent=1), encoding="utf-8")


if __name__ == "__main__":
    main()
