"""일과 생성 프롬프트 평가 하네스 공통: 서버 설정 읽기, Gemini 호출, 프롬프트 추출, 사용자 메시지 조립

서버(GeminiTextClient, GeminiImageClient)가 보내는 요청과 같은 모양으로 직접 호출한다.
API 키는 application-dev.yml 에서 읽고 화면·로그·결과 파일에 남기지 않는다.
"""
import base64
import json
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent
SERVER_DIR = TOOL_DIR.parent.parent
JAVA_ROOT = SERVER_DIR / "src/main/java/com/chuseok22/elumserver"
RESOURCES_DIR = SERVER_DIR / "src/main/resources"

# 평가 중 쓰는 호출 한도: 서버 기본 30초보다 넉넉히
REQUEST_TIMEOUT_SECONDS = 120
MAX_RETRY_COUNT = 3
RETRY_WAIT_SECONDS = 4


def load_gemini_settings() -> dict:
    """application-dev.yml 의 gemini: 블록 (api-key, base-url, text-model, image-model)"""
    text = (RESOURCES_DIR / "application-dev.yml").read_text(encoding="utf-8")
    block = re.search(r"^gemini:\n((?:[ ]{2}.*\n?)+)", text, re.MULTILINE)
    if not block:
        raise RuntimeError("application-dev.yml 에 gemini: 블록이 없음")
    settings = {}
    for line in block.group(1).splitlines():
        match = re.match(r"\s+([\w-]+):\s*(.*?)\s*$", line)
        if match:
            settings[match.group(1)] = match.group(2).strip("\"'")
    if not settings.get("api-key"):
        raise RuntimeError("gemini.api-key 가 비어 있음")
    return settings


def _post_json(url: str, api_key: str, body: dict) -> dict:
    """Gemini REST 호출 (일시 오류 429/5xx 는 재시도)"""
    data = json.dumps(body, ensure_ascii=False).encode("utf-8")
    last_error = None
    for attempt in range(1, MAX_RETRY_COUNT + 1):
        request = urllib.request.Request(
            url, data=data, method="POST",
            headers={"Content-Type": "application/json", "x-goog-api-key": api_key},
        )
        try:
            with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT_SECONDS) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            last_error = f"HTTP {error.code}: {error.read().decode('utf-8', 'replace')[:300]}"
            if error.code not in (429, 500, 502, 503, 504):
                break
        except Exception as error:  # 네트워크, 타임아웃
            last_error = repr(error)
        time.sleep(RETRY_WAIT_SECONDS * attempt)
    raise RuntimeError(last_error)


def extract_java_text_block(java_file: Path, prompt_key: str) -> str:
    """PromptDefaults 의 Map.entry(PromptKey.X, \"\"\"...\"\"\") 본문 (들여쓰기 제거, 줄 끝 \\ 이음 처리)"""
    source = java_file.read_text(encoding="utf-8")
    match = re.search(
        r'Map\.entry\(PromptKey\.' + re.escape(prompt_key) + r',\s*"""\n(.*?)"""\)', source, re.DOTALL
    )
    if not match:
        raise RuntimeError(f"{prompt_key} 텍스트 블록을 찾지 못함")
    lines = match.group(1).split("\n")
    indents = [len(line) - len(line.lstrip()) for line in lines if line.strip()]
    margin = min(indents) if indents else 0
    stripped = "\n".join(line[margin:] if line.strip() else "" for line in lines)
    return stripped.replace("\\\n", "").replace('\\"', '"')


def baseline_prompt(prompt_key: str) -> str:
    """현재 코드 기본값 프롬프트 (운영 DB 값과 다를 수 있음)"""
    return extract_java_text_block(JAVA_ROOT / "ai/core/PromptDefaults.java", prompt_key)


def pictogram_ids() -> list:
    catalog = json.loads((RESOURCES_DIR / "pictograms/catalog.json").read_text(encoding="utf-8"))
    return [symbol["id"] for symbol in catalog["symbols"]]


def character_reference_png(character: str) -> bytes:
    return (RESOURCES_DIR / f"static/characters/{character.lower()}.png").read_bytes()


# 서버 CharacterType.appearance 와 같은 문장 (한국어)
CHARACTER_APPEARANCE_KO = {
    "LULU": "아이보리색(#EFEDE8) 둥근 아기 고양이. 몸이 얼굴만큼 크고 통통하며 다리가 아주 짧다. "
            "귀는 삼각형이고 안쪽이 연분홍색이다. 눈은 점처럼 작고 동그란 검은색이며 "
            "코는 작은 분홍색 삼각형, 입은 짧은 곡선 두 개다. 꼬리는 가늘고 길게 옆으로 뻗는다.",
    "POPO": "주황색(#FF8B26) 아기 여우. 몸이 둥글고 다리가 아주 짧다. 귀는 뾰족한 삼각형이고 "
            "안쪽이 크림색이다. 배와 가슴, 꼬리 끝이 크림색이다. 눈은 점처럼 작고 동그란 검은색이며 "
            "코는 작은 검은 점, 입은 짧은 곡선이다.",
}

STEP_TITLE_HINT = "카드에 크게 표시할 2~4어절짜리 짧은 라벨. '~해요' 체 (예: '옷을 입어요')"
STEP_DESCRIPTION_HINT = (
    "소리 내어 읽어줄 아주 짧은 한 문장. 공백 포함 12자 안팎, 행동 하나만. "
    "title을 되풀이하지 않고 쉬운 말로 (예: '학교 갈 옷을 입어요')"
)
ROUTINE_TITLE_HINT = "일과 전체를 아우르는 제목. '~해요' 체로 작성 (예: '비오는 날 학교에 가요')"


def routine_response_schema(extra_step_properties: dict = None, description_hint: str = None) -> dict:
    """GeminiRoutineSchemas.responseSchema(false, true) 와 같은 모양 (+ 실험용 단계 필드)"""
    step_properties = {
        "order": {"type": "integer"},
        "title": {"type": "string", "minLength": 1, "description": STEP_TITLE_HINT},
        "description": {"type": "string", "description": description_hint or STEP_DESCRIPTION_HINT},
        "pictogramId": {
            "type": "string", "nullable": True,
            "description": "pictogramCatalog 안에서 이 단계의 행동이나 사물을 가장 잘 나타내는 id 하나. "
                           "알맞은 것이 없거나 확신이 없으면 null. 억지로 고르지 마세요(비슷하지만 뜻이 다른 것 금지)",
        },
    }
    required = ["order", "title", "description"]
    for name, spec in (extra_step_properties or {}).items():
        step_properties[name] = spec
        required.append(name)
    return {
        "type": "object",
        "properties": {
            "title": {"type": "string", "description": ROUTINE_TITLE_HINT},
            "steps": {
                "type": "array", "maxItems": 10,
                "items": {"type": "object", "properties": step_properties, "required": required},
            },
        },
        "required": ["title", "steps"],
    }


def question_response_schema(goal_count: int, hints: dict = None) -> dict:
    hints = hints or {}
    option = {
        "type": "object",
        "properties": {
            "emoji": {"type": "string", **({"description": hints["option_emoji_hint"]} if "option_emoji_hint" in hints else {})},
            "label": {"type": "string", **({"description": hints["option_label_hint"]} if "option_label_hint" in hints else {})},
        },
        "required": ["emoji", "label"],
    }
    item = {
        "type": "object",
        "properties": {
            "supportGoal": {"type": "string", "enum": ["PREPARE_ITEMS", "PREPARE_NEW"]},
            "question": {"type": "string", **({"description": hints["question_hint"]} if "question_hint" in hints else {})},
            "options": {"type": "array", "minItems": 3, "maxItems": 5, "items": option},
        },
        "required": ["supportGoal", "question", "options"],
    }
    return {
        "type": "object",
        "properties": {"questions": {"type": "array", "minItems": goal_count, "maxItems": goal_count, "items": item}},
        "required": ["questions"],
    }


def create_user_content(routine_text: str, support_goals: list, answers: list, include_catalog: bool = True) -> str:
    """RoutineCreateAiInput JSON (이름은 서버가 '이룸이' 자리표시로 바꿔 보낸다)"""
    payload = {
        "task": "CREATE_ROUTINE",
        "routineText": routine_text,
        "childProfile": {"nickname": "이룸이", "supportGoals": support_goals},
        "additionalAnswers": answers,
        "pictogramCatalog": pictogram_ids() if include_catalog else [],
    }
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def question_user_content(routine_text: str, support_goals: list) -> str:
    payload = {
        "task": "GENERATE_ROUTINE_QUESTIONS",
        "routineText": routine_text,
        "childProfile": {"nickname": "이룸이", "supportGoals": support_goals},
    }
    return json.dumps(payload, ensure_ascii=False, separators=(",", ":"))


def call_text_model(system_prompt: str, user_content: str, schema: dict, settings: dict) -> tuple:
    """Gemini 텍스트 호출 > (응답 JSON 객체, 경과 초, 토큰 사용량)"""
    body = {
        "systemInstruction": {"parts": [{"text": system_prompt}]},
        "contents": [{"role": "user", "parts": [{"text": user_content}]}],
        "generationConfig": {
            "responseMimeType": "application/json", "responseSchema": schema, "temperature": 0,
        },
    }
    url = f"{settings['base-url']}/v1beta/models/{settings['text-model']}:generateContent"
    started = time.time()
    response = _post_json(url, settings["api-key"], body)
    elapsed = time.time() - started
    parts = response["candidates"][0]["content"]["parts"]
    text = "".join(part.get("text", "") for part in parts)
    return json.loads(text), elapsed, response.get("usageMetadata", {})


def call_image_model(prompt_text: str, character: str, settings: dict, aspect_ratio: str = "4:3") -> tuple:
    """Gemini 이미지 호출 > (PNG 바이트, 경과 초). 캐릭터 참조 PNG 를 텍스트보다 먼저 싣는다."""
    parts = []
    if character:
        encoded = base64.b64encode(character_reference_png(character)).decode("ascii")
        parts.append({"inlineData": {"mimeType": "image/png", "data": encoded}})
    parts.append({"text": prompt_text})
    body = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "responseModalities": ["TEXT", "IMAGE"], "imageConfig": {"aspectRatio": aspect_ratio},
        },
    }
    url = f"{settings['base-url']}/v1beta/models/{settings['image-model']}:generateContent"
    started = time.time()
    response = _post_json(url, settings["api-key"], body)
    elapsed = time.time() - started
    for candidate in response.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return base64.b64decode(inline["data"]), elapsed
    raise RuntimeError("응답에 이미지 데이터가 없음")


def image_prompt(prefix: str, scene: dict, character: str, reference_provided: bool = True) -> str:
    """GeminiRoutineImagePromptBuilder.build(KO) 와 같은 조립: 지시문 + 빈 줄 + '장면 정보:' + JSON"""
    payload = {
        "task": "CREATE_ROUTINE_CARD_IMAGE",
        "scene": scene,
        "character": {
            "type": character, "appearance": CHARACTER_APPEARANCE_KO[character],
            "referenceImageProvided": reference_provided,
        },
    }
    return prefix + "\n\n장면 정보:\n" + json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
