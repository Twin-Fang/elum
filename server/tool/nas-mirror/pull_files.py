#!/usr/bin/env python3
"""원본(친구 서버) 파일 > 내 NAS: 관리자 로그인 > 종류별 목록 > 없거나 해시가 다른 파일만 받기 > 해시 확인 뒤 저장 (#1054)

원본 서버의 파일 내보내기 API(#1053)를 쓴다. 원본 시스템 설정 "이전 파일 내보내기"가 켜져 있어야 한다.
원본 목록에 없는 내 NAS 파일은 지우지 않고 보고만 한다.

사용 (내 NAS 에서 root, mirror.env 를 읽은 셸):
  python3 pull_files.py                 # 받기
  python3 pull_files.py --verify-only   # 받지 않고 비교만 (정합성 검사, 차이가 있으면 종료 코드 1)

환경변수 (mirror.env):
  SOURCE_ADMIN_BASE_URL  원본 서버 주소 (예: https://api.elum.chuseok22.com)
  SOURCE_ADMIN_USERNAME  원본 관리자 아이디
  SOURCE_ADMIN_PASSWORD  원본 관리자 비밀번호
  APP_DATA_DIR           내 NAS 파일 폴더 (기본 /volume1/project/elum/server/data)
"""
import argparse
import hashlib
import http.client
import http.cookiejar
import json
import os
import re
import sys
import urllib.parse
import urllib.request

# 내보내기 종류 = 내 NAS data/ 아래 폴더 이름 (서버 저장소 기본 경로와 같음)
AREAS = ("routine-images", "talk-images", "notice-images", "routine-speech")
LOGIN_PATH = "/admin/login"
LIST_PATH = "/admin/migration/api/files"
DOWNLOAD_PATH = "/admin/migration/api/files/download"
# 로그인 폼의 CSRF 숨은 칸 (Spring Security 기본 이름)
CSRF_INPUT_PATTERN = re.compile(r'name="_csrf"\s+value="([^"]+)"|value="([^"]+)"\s+name="_csrf"')
REQUEST_TIMEOUT_SECONDS = 60
# 파일 하나 받기 재시도 (긴 전송 중 끊김 대비)
DOWNLOAD_ATTEMPT_COUNT = 3
READ_CHUNK_BYTES = 1024 * 1024
DEFAULT_DATA_DIR = "/volume1/project/elum/server/data"


def log(message):
    print("[pull files] " + message, flush=True)


def fail(message):
    print("[pull files] failed : " + message, file=sys.stderr, flush=True)
    sys.exit(1)


def require_env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        fail(name + " is empty (mirror.env)")
    return value


def build_opener():
    cookie_jar = http.cookiejar.CookieJar()
    return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cookie_jar))


def login(opener, base_url, username, password):
    """로그인 화면 > CSRF 값 > 폼 제출 > 세션 쿠키 (실패하면 로그인 화면으로 돌아옴)"""
    with opener.open(base_url + LOGIN_PATH, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        page = response.read().decode("utf-8", "replace")
    match = CSRF_INPUT_PATTERN.search(page)
    if not match:
        fail("csrf token not found on login page")
    csrf_token = match.group(1) or match.group(2)
    form = urllib.parse.urlencode({"username": username, "password": password, "_csrf": csrf_token}).encode()
    with opener.open(base_url + LOGIN_PATH, data=form, timeout=REQUEST_TIMEOUT_SECONDS) as response:
        landed_path = urllib.parse.urlparse(response.geturl()).path
    if landed_path.startswith(LOGIN_PATH):
        fail("admin login rejected (check SOURCE_ADMIN_USERNAME / SOURCE_ADMIN_PASSWORD)")
    log("admin login ok")


def fetch_listing(opener, base_url, area):
    url = base_url + LIST_PATH + "?" + urllib.parse.urlencode({"area": area})
    try:
        with opener.open(url, timeout=REQUEST_TIMEOUT_SECONDS) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        if error.code == 404:
            fail("export disabled on source (turn on 이전 파일 내보내기) or source not deployed yet")
        fail("listing " + area + " http " + str(error.code))


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as file:
        for chunk in iter(lambda: file.read(READ_CHUNK_BYTES), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_same_file(path, expected_size, expected_sha256):
    return os.path.isfile(path) and os.path.getsize(path) == expected_size and sha256_of(path) == expected_sha256


def safe_local_path(area_dir, relative_path):
    """원본이 준 상대 경로 > 내 NAS 경로 (폴더 밖으로 나가면 거부)"""
    target = os.path.normpath(os.path.join(area_dir, relative_path))
    if not target.startswith(os.path.normpath(area_dir) + os.sep):
        fail("unsafe path from source : " + relative_path)
    return target


def download(opener, base_url, area, entry, target):
    """.part 로 받기 > 크기·해시 확인 > 이름 바꾸기, 끊기거나 다르면 최대 3번 (옛 파일은 깨지지 않음)"""
    url = base_url + DOWNLOAD_PATH + "?" + urllib.parse.urlencode({"area": area, "path": entry["path"]})
    os.makedirs(os.path.dirname(target), exist_ok=True)
    partial = target + ".part"
    for attempt in range(1, DOWNLOAD_ATTEMPT_COUNT + 1):
        try:
            with opener.open(url, timeout=REQUEST_TIMEOUT_SECONDS) as response, open(partial, "wb") as file:
                content_type = response.headers.get("Content-Type", "")
                for chunk in iter(lambda: response.read(READ_CHUNK_BYTES), b""):
                    file.write(chunk)
            if is_same_file(partial, entry["size"], entry["sha256"]):
                os.replace(partial, target)
                return
            reason = "got {} bytes ({}), expected {}".format(os.path.getsize(partial), content_type, entry["size"])
        except (OSError, http.client.HTTPException) as error:
            reason = error.__class__.__name__
        if os.path.exists(partial):
            os.remove(partial)
        log("retry {}/{} : {}/{} ({})".format(attempt, DOWNLOAD_ATTEMPT_COUNT, area, entry["path"], reason))
    fail("download failed after {} attempts : {}/{}".format(DOWNLOAD_ATTEMPT_COUNT, area, entry["path"]))


def local_files(area_dir):
    found = set()
    for root, _, names in os.walk(area_dir):
        for name in names:
            if name.endswith(".part"):
                continue
            found.add(os.path.relpath(os.path.join(root, name), area_dir).replace(os.sep, "/"))
    return found


def sync_area(opener, base_url, data_dir, area, is_verify_only):
    """종류 하나: 목록 > 같은 파일 건너뜀 > 나머지 받기(또는 차이로 셈) > 원본에 없는 내 파일 보고"""
    listing = fetch_listing(opener, base_url, area)
    area_dir = os.path.join(data_dir, area)
    source_paths = set()
    same_count = 0
    changed_count = 0
    for entry in listing["files"]:
        source_paths.add(entry["path"])
        target = safe_local_path(area_dir, entry["path"])
        if is_same_file(target, entry["size"], entry["sha256"]):
            same_count += 1
            continue
        changed_count += 1
        if not is_verify_only:
            download(opener, base_url, area, entry, target)
    extra_paths = sorted(local_files(area_dir) - source_paths) if os.path.isdir(area_dir) else []
    action = "different" if is_verify_only else "downloaded"
    log("{} : source={} files {} bytes, same={}, {}={}, local-only={}".format(
        area, listing["fileCount"], listing["totalBytes"], same_count, action, changed_count, len(extra_paths)))
    for path in extra_paths[:20]:
        log("  local-only : " + area + "/" + path)
    return changed_count


def main():
    parser = argparse.ArgumentParser(description="pull migration files from source server")
    parser.add_argument("--verify-only", action="store_true", help="compare only, exit 1 if any file differs")
    args = parser.parse_args()

    base_url = require_env("SOURCE_ADMIN_BASE_URL").rstrip("/")
    username = require_env("SOURCE_ADMIN_USERNAME")
    password = require_env("SOURCE_ADMIN_PASSWORD")
    data_dir = os.environ.get("APP_DATA_DIR", DEFAULT_DATA_DIR)

    opener = build_opener()
    login(opener, base_url, username, password)
    total_changed = sum(sync_area(opener, base_url, data_dir, area, args.verify_only) for area in AREAS)
    if args.verify_only and total_changed > 0:
        fail("files differ : " + str(total_changed))
    log("done : " + ("all files match" if args.verify_only else "changed " + str(total_changed)))


if __name__ == "__main__":
    main()
