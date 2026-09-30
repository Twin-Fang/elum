#!/usr/bin/env python3
# ===================================================================
# asc_released_version.py — 이미 출시된(닫힌) 버전인지 사전 점검 (이슈 #452)
# ===================================================================
#
# 왜 필요한가
#   App Store에 출시(승인)된 버전은 TestFlight 자리(prerelease train)가 영구히 닫힌다.
#   그 버전 이름으로 올린 테스트 빌드는 빌드 번호가 아무리 커도 업로드에서 거부된다:
#     Invalid Pre-Release Train. The train version '2.1.2' is closed for new build submissions
#   IPA 를 12~18분 만든 뒤에야 알게 되므로, 빌드를 시작하기 전에 App Store Connect 를 읽어 미리 멈춘다.
#
# 사용:  asc_released_version.py <이번 빌드 버전>
# 환경변수:
#   APP_STORE_CONNECT_API_KEY_ID / _ISSUER_ID / _API_KEY_BASE64   (.p8 를 base64 한 값)
#   IOS_BUNDLE_ID                                                  (앱 번들 ID)
#   ASC_API_BASE                                                   (시험용 — 기본은 Apple 서버)
#
# 출력: stdout 에 `key=value` 줄 (GITHUB_OUTPUT 에 그대로 붙일 수 있다).
#   status=ok        이번 버전이 출시된 최대 버전보다 높다 — 빌드해도 된다
#   status=blocked   출시된 버전과 같거나 낮다 — 업로드가 거부된다
#   status=skipped   조회하지 못했다(키 없음·네트워크·응답 이상) — **막지 않는다**
#   released_max=... 출시된 최대 버전 (알 때만)
#   reason=...       한 줄 사유 (사람이 읽는 문장)
# 종료코드는 항상 0 이다 — 판단은 status 로 한다. 조회 실패가 빌드를 막으면
# 지금까지 되던 빌드까지 깨뜨리므로 실패는 열어 둔다(fail-open).
#
# 표준 라이브러리 + openssl 만 쓴다(PyJWT 없음). JWT(ES256) 서명은 openssl 로 한다.
# ===================================================================

import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

API_BASE_DEFAULT = "https://api.appstoreconnect.apple.com"

# 심사를 통과해 출시 절차에 들어간(=train 이 닫힌) 상태.
# 준비 중·심사 대기·심사 중·거절 같은 상태는 아직 열려 있으므로 넣지 않는다.
CLOSED_STATES = {
    "READY_FOR_SALE",
    "PENDING_DEVELOPER_RELEASE",
    "PENDING_APPLE_RELEASE",
    "PROCESSING_FOR_APP_STORE",
    "REPLACED_WITH_NEW_VERSION",
    "REMOVED_FROM_SALE",
    "DEVELOPER_REMOVED_FROM_SALE",
}

_VERSION_RE = re.compile(r"^\d+(\.\d+){0,2}$")


def parse_version(text):
    """'2.1.2' -> (2, 1, 2). 숫자 점 표기가 아니면 None."""
    text = (text or "").strip()
    if not _VERSION_RE.match(text):
        return None
    parts = [int(p) for p in text.split(".")]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts)


def released_max(versions):
    """[(versionString, state), ...] 에서 닫힌 버전의 최대값을 (문자열, 튜플)로."""
    best = None
    for version_string, state in versions:
        if state not in CLOSED_STATES:
            continue
        parsed = parse_version(version_string)
        if parsed is None:
            continue
        if best is None or parsed > best[1]:
            best = (version_string, parsed)
    return best


def decide(current, versions):
    """이번 빌드 버전이 막히는지 판정한다. (status, released_max 문자열, reason)."""
    current_parsed = parse_version(current)
    if current_parsed is None:
        return "skipped", "", f"이번 빌드 버전 '{current}' 을 숫자 표기로 읽지 못해 점검하지 않았다"

    best = released_max(versions)
    if best is None:
        return "ok", "", "출시된 버전이 없어 막히지 않는다"

    best_string, best_parsed = best
    if current_parsed <= best_parsed:
        return (
            "blocked",
            best_string,
            f"버전 {current} 은(는) 이미 App Store 에 출시된 버전 {best_string} 이하라 "
            f"TestFlight 자리가 닫혀 있다(빌드 번호가 커도 업로드가 거부된다). "
            f"다음 릴리스로 버전이 올라간 뒤에 다시 시도하라",
        )
    return "ok", best_string, f"출시된 최대 버전 {best_string} 보다 높아 빌드해도 된다"


# ── App Store Connect 조회 ─────────────────────────────────────────
def _b64url(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def _der_to_raw(der):
    """openssl 이 내는 DER(ECDSA) 서명을 JWT 가 요구하는 R||S 64바이트로 바꾼다."""
    idx = 2 if der[1] < 0x80 else 3
    r_len = der[idx + 1]
    r = der[idx + 2 : idx + 2 + r_len]
    idx = idx + 2 + r_len
    s_len = der[idx + 1]
    s = der[idx + 2 : idx + 2 + s_len]
    return r.lstrip(b"\x00").rjust(32, b"\x00") + s.lstrip(b"\x00").rjust(32, b"\x00")


def make_token(key_pem, key_id, issuer_id):
    header = _b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}, separators=(",", ":")).encode())
    payload = _b64url(
        json.dumps(
            {"iss": issuer_id, "exp": int(time.time()) + 600, "aud": "appstoreconnect-v1"},
            separators=(",", ":"),
        ).encode()
    )
    signing_input = f"{header}.{payload}".encode()
    with tempfile.NamedTemporaryFile("w", suffix=".p8", delete=False) as fh:
        fh.write(key_pem)
        key_path = fh.name
    try:
        os.chmod(key_path, 0o600)
        der = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path],
            input=signing_input, capture_output=True, check=True, timeout=20,
        ).stdout
    finally:
        os.remove(key_path)
    return f"{header}.{payload}.{_b64url(_der_to_raw(der))}"


def _get(base, path, token):
    request = urllib.request.Request(base + path, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read())


def fetch_versions(base, token, bundle_id):
    """번들 ID 로 앱을 찾아 iOS 앱 버전 목록 [(versionString, appStoreState)] 을 읽는다."""
    query = urllib.parse.quote(bundle_id, safe="")
    apps = _get(base, f"/v1/apps?filter[bundleId]={query}&limit=1", token).get("data", [])
    if not apps:
        raise RuntimeError(f"번들 ID '{bundle_id}' 인 앱을 찾지 못했다")
    app_id = apps[0]["id"]
    body = _get(base, f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS&limit=200", token)
    return [
        (item["attributes"].get("versionString", ""), item["attributes"].get("appStoreState", ""))
        for item in body.get("data", [])
    ]


def emit(status, released, reason):
    # reason 은 GITHUB_OUTPUT 한 줄이어야 하므로 줄바꿈을 없앤다
    print(f"status={status}")
    if released:
        print(f"released_max={released}")
    print("reason=" + " ".join(str(reason).split()))


def main(argv):
    if len(argv) != 2:
        emit("skipped", "", "사용법: asc_released_version.py <이번 빌드 버전>")
        return 0
    current = argv[1]

    key_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ID", "").strip()
    issuer_id = os.environ.get("APP_STORE_CONNECT_ISSUER_ID", "").strip()
    key_b64 = os.environ.get("APP_STORE_CONNECT_API_KEY_BASE64", "").strip()
    bundle_id = os.environ.get("IOS_BUNDLE_ID", "").strip()
    if not (key_id and issuer_id and key_b64 and bundle_id):
        emit("skipped", "", "App Store Connect 조회에 필요한 시크릿/번들 ID 가 없어 사전 점검을 건너뛴다")
        return 0

    try:
        key_pem = base64.b64decode(key_b64).decode()
        token = make_token(key_pem, key_id, issuer_id)
        versions = fetch_versions(os.environ.get("ASC_API_BASE", API_BASE_DEFAULT), token, bundle_id)
    except urllib.error.HTTPError as error:
        emit("skipped", "", f"App Store Connect 조회가 HTTP {error.code} 로 실패해 사전 점검을 건너뛴다")
        return 0
    except Exception as error:  # 조회 실패가 빌드를 막지 않게 넓게 받는다
        emit("skipped", "", f"App Store Connect 조회에 실패해 사전 점검을 건너뛴다({type(error).__name__})")
        return 0

    status, released, reason = decide(current, versions)
    emit(status, released, reason)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
