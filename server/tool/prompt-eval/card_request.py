"""행동카드 요청 조립: 운영 지시문 + Claude 보강 + strict 스키마 + 사용자 입력 > claude -p 호출

지시문은 운영 관리자 화면, 보강·스키마 문구는 origin/develop 자바 소스에서 읽어 사본을 두지 않는다.
"""
import html
import http.cookiejar
import json
import re
import subprocess
import tempfile
import urllib.parse
import urllib.request

import lib

ADMIN_BASE_URL = "https://api.elum.suhsaechan.kr"
JAVA_REF = "origin/develop"
CLAUDE_TEXT_CLIENT = "ai/infrastructure/client/ClaudeTextClient.java"
ROUTINE_SCHEMAS = "ai/infrastructure/client/GeminiRoutineSchemas.java"
PICTOGRAM_SPEC = "ai/infrastructure/client/GeminiPictogramPickSpec.java"
LANGUAGE_SPEC = "ai/core/ContentLanguageSpec.java"
# 운영 CLAUDE_TEXT_MODEL 값, CLAUDE_TEXT_EFFORT UNSET 은 Haiku 5.5 기본값 medium
TEXT_MODEL = "claude-haiku-5-5"
TEXT_EFFORT = "medium"
CALL_TIMEOUT_SECONDS = 180
UNSUPPORTED_STRICT_KEYWORDS = {"minItems", "maxItems", "minLength", "maxLength"}


def load_env_local() -> dict:
    """.env.local (커밋 안 됨): 관리자 계정"""
    env_file = lib.TOOL_DIR / ".env.local"
    pairs = (line.split("=", 1) for line in env_file.read_text(encoding="utf-8").splitlines() if "=" in line)
    return {name.strip(): value.strip() for name, value in pairs}


class AdminSession:
    """운영 관리자 세션: 로그인, 설정·지시문 읽기, 그림 시험 (설정 저장은 하지 않음)"""

    def __init__(self):
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
        self._login()

    def _get(self, path: str) -> str:
        return self.opener.open(ADMIN_BASE_URL + path, timeout=30).read().decode("utf-8")

    def _login(self):
        token = re.search(r'name="_csrf"[^>]*value="([^"]+)"', self._get("/admin/login")).group(1)
        env = load_env_local()
        form = {"username": env["ELUM_ADMIN_USERNAME"], "password": env["ELUM_ADMIN_PASSWORD"], "_csrf": token}
        response = self.opener.open(
            urllib.request.Request(ADMIN_BASE_URL + "/admin/login", data=urllib.parse.urlencode(form).encode()),
            timeout=30)
        if "login" in response.geturl():
            raise RuntimeError("관리자 로그인 실패")

    def read_prompt(self, prompt_key: str) -> str:
        """관리자 지시문 화면의 textarea 본문 (운영 DB 값)"""
        page = self._get("/admin/prompts?locale=ko")
        match = re.search(r'data-key="' + prompt_key + r'">(.*?)</textarea>', page, re.DOTALL)
        if not match:
            raise RuntimeError(f"{prompt_key} 지시문을 찾지 못함")
        return html.unescape(match.group(1)).strip()

    def read_settings(self, keys: list) -> dict:
        """설정 화면 값 (비밀값은 읽지 않음)"""
        page = self._get("/admin/settings")
        settings = {}
        for key in keys:
            # 값이 비면 data-current 가 없는 행이 있어 다음 행으로 넘어가지 않게 행 안에서만 찾음
            pattern = r'data-key="' + key + r'"(?:(?!data-config-row).)*?data-current="([^"]*)"'
            match = re.search(pattern, page, re.DOTALL)
            settings[key] = html.unescape(match.group(1)) if match else None
        return settings

    def test_image(self, prefix: str, scene_text: str, character: str) -> str:
        """관리자 그림 시험 (실제 그림 호출, 비용 발생) > data URI"""
        token = re.search(r'name="_csrf" content="([^"]+)"', self._get("/admin/prompts?locale=ko")).group(1)
        body = json.dumps({"content": prefix, "sampleInput": scene_text, "character": character}).encode("utf-8")
        request = urllib.request.Request(
            ADMIN_BASE_URL + "/admin/prompts/ROUTINE_IMAGE_PREFIX_EN/test", data=body, method="POST",
            headers={"Content-Type": "application/json", "X-CSRF-TOKEN": token})
        return json.loads(self.opener.open(request, timeout=180).read().decode("utf-8"))["imageDataUri"]


def read_java_string(relative_path: str, constant_name: str) -> str:
    """자바 문자열 상수 > 본문 (일반 문자열 이어 붙이기, 텍스트 블록 둘 다)"""
    source = lib._java_source(relative_path, JAVA_REF)
    block = re.search(constant_name + r'\s*=\s*"""\n(.*?)""";', source, re.DOTALL)
    if block:
        return lib._dedent_text_block(block.group(1))
    joined = re.search(constant_name + r'\s*=\s*((?:\s*\+?\s*"(?:[^"\\]|\\.)*")+)\s*;', source)
    if not joined:
        raise RuntimeError(f"{constant_name} 상수를 찾지 못함")
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', joined.group(1))
    return "".join(parts).replace('\\"', '"').replace("\\n", "\n")


def to_strict_schema(source):
    """StrictJsonSchemas.from 과 같은 변환 (길이 제약 제거, nullable > type 목록, 전 필드 required)"""
    if isinstance(source, list):
        return [to_strict_schema(entry) for entry in source]
    if not isinstance(source, dict):
        return source
    converted = {key: to_strict_schema(value) for key, value in source.items() if key not in UNSUPPORTED_STRICT_KEYWORDS}
    if converted.pop("nullable", False) and isinstance(converted.get("type"), str):
        converted["type"] = [converted["type"], "null"]
    if source.get("type") == "object":
        converted["required"] = list(converted.get("properties", {}))
        converted["additionalProperties"] = False
    return converted


def build_routine_schema() -> dict:
    """GeminiRoutineSchemas.responseSchema(true, true) + strict 변환"""
    step_properties = {
        "order": {"type": "integer"},
        "title": {"type": "string", "description": read_java_string(LANGUAGE_SPEC, "KO_STEP_TITLE_HINT")},
        "description": {"type": "string", "description": read_java_string(LANGUAGE_SPEC, "KO_STEP_DESCRIPTION_HINT")},
        "pictogramId": {"type": "string", "nullable": True,
                        "description": read_java_string(PICTOGRAM_SPEC, "PICTOGRAM_ID_DESCRIPTION")},
        "imagePromptEn": {"type": "string",
                          "description": read_java_string(ROUTINE_SCHEMAS, "IMAGE_PROMPT_EN_DESCRIPTION")},
    }
    return to_strict_schema({
        "type": "object",
        "properties": {
            "title": {"type": "string", "description": read_java_string(LANGUAGE_SPEC, "KO_ROUTINE_TITLE_HINT")},
            "steps": {"type": "array", "maxItems": 10, "items": {"type": "object", "properties": step_properties}},
        },
    })


def build_system_prompt(production_prompt: str, variant_text: str = "") -> str:
    """운영 지시문 + (시험할 추가 지시) + Claude 보강. 서버와 같은 순서"""
    supplement = read_java_string(CLAUDE_TEXT_CLIENT, "ROUTINE_CREATE_SUPPLEMENT")
    middle = f"\n\n{variant_text.strip()}" if variant_text.strip() else ""
    return production_prompt + middle + supplement


def build_replaced_system_prompt(full_prompt: str) -> str:
    """지시문 전체 교체 변형 + Claude 보강"""
    return full_prompt.strip() + read_java_string(CLAUDE_TEXT_CLIENT, "ROUTINE_CREATE_SUPPLEMENT")


def call_claude_for_card(system_prompt: str, schema: dict, user_content: str, effort: str = TEXT_EFFORT) -> dict:
    """claude -p 1회 (도구·프로젝트 설정·세션 저장 없음, 스키마 강제) > 카드 JSON + 비용"""
    command = [
        "claude", "-p", "--model", TEXT_MODEL, "--effort", effort, "--tools", "",
        "--no-session-persistence", "--strict-mcp-config", "--setting-sources", "",
        "--disable-slash-commands", "--system-prompt", system_prompt,
        "--json-schema", json.dumps(schema, ensure_ascii=False), "--output-format", "json",
    ]
    # 프로젝트 CLAUDE.md 가 끼지 않게 빈 폴더에서 실행
    with tempfile.TemporaryDirectory() as empty_folder:
        completed = subprocess.run(
            command, input=user_content, capture_output=True, text=True,
            timeout=CALL_TIMEOUT_SECONDS, cwd=empty_folder)
    if completed.returncode != 0 and not completed.stdout.strip():
        raise RuntimeError(f"claude 실행 실패: {completed.stderr[:300]}")
    envelope = json.loads(completed.stdout)
    if envelope.get("is_error") or not envelope.get("structured_output"):
        raise RuntimeError(f"응답 오류: {str(envelope.get('result'))[:300]}")
    return {
        "card": envelope["structured_output"],
        "cost_usd": envelope.get("total_cost_usd", 0),
        "elapsed_seconds": round(envelope.get("duration_ms", 0) / 1000, 1),
    }
