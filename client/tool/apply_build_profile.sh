#!/usr/bin/env bash
#
# 빌드 종류에 맞게 **런타임 스위치와 컴파일타임 플래그를 함께** 맞춘다 (이슈 #220).
#
#   apply_build_profile.sh test    <.env 경로>   # QA·테스트 빌드 → 개발 도구 켬
#   apply_build_profile.sh release <.env 경로>   # 사용자에게 나가는 빌드 → 전부 끔
#
# ## 왜 둘을 한 곳에서 내보내나
#
# 플래그가 **두 층**에 있다.
#
#   런타임    `.env`          flutter_dotenv가 에셋으로 읽는다. Secret으로 주입된다.
#   컴파일타임 `--dart-define`  바이너리에 박힌다. Secret으로 위조할 수 없다.
#
# 기능 하나를 켜려면 **두 층이 모두 맞아야 한다.**
#
#   showDevTools = (kDebugMode || APP_FLAVOR == 'dev') && .env의 ELUM_SHOW_DEV_TOOLS
#                   └─ 컴파일타임 ─┘                      └─ 런타임 ─┘
#
# 예전에는 이 스크립트가 `.env`만 고치고 dart-define은 워크플로 빌드 명령에 따로 있었다.
# **그래서 한쪽만 적용돼도 아무도 몰랐다.** 실제로 `.env`에 `ELUM_SHOW_DEV_TOOLS=true`가
# 찍혔는데 QA가 받은 앱에는 디버깅 버튼이 없었다 — 릴리스 빌드라 `kDebugMode`가 false고
# 플레이버가 비어 있었다.
#
# 이제 **프로파일 하나가 두 층을 모두 정한다.** 워크플로는 이 스크립트를 부르고
# 출력된 빌드 플래그를 빌드 명령에 그대로 넘긴다. 한쪽만 적용되는 경우가 없다.
#
# ## 워크플로에서 쓰는 법
#
#   - name: 빌드 프로파일 적용 (test)
#     id: build_profile
#     run: bash "${{ github.workspace }}/client/tool/apply_build_profile.sh" test .env
#
#   - name: Flutter build
#     run: flutter build apk --release ${{ steps.build_profile.outputs.build_flags }}
#
# `release` 프로파일은 `build_flags`가 **빈 문자열**이다 — 기본값(prod)이 곧 안전장치다.
#
# ## `sed -i`를 쓰지 않는다
#
# GNU sed(`-i`)와 BSD sed(`-i ''`) 문법이 갈려 Linux 러너와 macOS 러너에서 동작이 다르다.
# 조용히 통과하고 아무것도 안 바뀌는 사고가 실제로 있었다(projectops #523).
# grep으로 걸러 다시 쓰는 방식은 양쪽에서 똑같이 동작한다.

set -euo pipefail

MODE="${1:-}"
ENV_FILE="${2:-}"

if [ -z "$MODE" ] || [ -z "$ENV_FILE" ]; then
  echo "사용법: $0 <test|release> <.env 경로>" >&2
  exit 2
fi
if [ ! -f "$ENV_FILE" ]; then
  echo "::error::.env 파일이 없습니다: $ENV_FILE" >&2
  exit 1
fi

# ── 프로파일 정의 — 여기만 고치면 모든 빌드에 반영된다 ────────────────
#
# 런타임 개발 키. `.env`에서 이 이름으로 시작하는 줄을 걷어낸 뒤 프로파일대로 다시 쓴다.
#   ELUM_SHOW_DEV_TOOLS      디버깅 버튼 (토큰·PIN을 평문으로 보여준다)
#   ELUM_ENABLE_NETWORK_LOG  요청·응답 본문을 로그에 남긴다
#   ELUM_SKIP_ONBOARDING     온보딩 건너뛰기 (PIN 미설정 상태가 된다)
#   ELUM_USE_MOCK            서버 대신 가짜 데이터
#   ELUM_DEV_*_TOKEN         QA 세션 주입용
DEV_KEYS=(
  ELUM_SHOW_DEV_TOOLS
  ELUM_ENABLE_NETWORK_LOG
  ELUM_SKIP_ONBOARDING
  ELUM_USE_MOCK
  ELUM_DEV_ACCESS_TOKEN
  ELUM_DEV_REFRESH_TOKEN
)

# 테스트 빌드에서 켤 런타임 스위치.
# 여기 없는 키는 테스트 빌드에서도 꺼진 채로 둔다 — `ELUM_USE_MOCK`은 서버 대신 가짜
# 데이터를 쓰므로 QA가 진짜를 못 본다. 토큰은 사람마다 달라 CI가 정할 수 없다.
TEST_ENV=(
  "ELUM_SHOW_DEV_TOOLS=true"
  "ELUM_ENABLE_NETWORK_LOG=true"
)

# 테스트 빌드의 컴파일타임 플래그.
#
# `APP_FLAVOR`는 **앱 이름이 안 들어가는 중립적인 이름**이다 — CI 템플릿이 앱을 몰라도 된다.
#
# Flutter 표준인 `FLUTTER_APP_FLAVOR`를 쓰려 했으나 **CLI가 예약어로 막는다**:
#   FLUTTER_APP_FLAVOR is used by the framework and cannot be set using --dart-define
# 그 값은 `--flavor`로만 설정되고, `--flavor`는 Gradle productFlavors와 Xcode scheme을
# 갖춰야 한다. 불리언 하나 때문에 치를 값이 아니라 중립적인 이름을 직접 쓴다.
#
# 위조를 막으려고 일부러 `.env` 밖에 둔다 (이슈 #130) — Secret에 잘못된 값이 들어가도
# mock으로 도는 앱이 스토어에 나가지 않는다.
#
# 나중에 `--flavor`를 갖추게 되면 여기와 AppConfig의 getter 두 곳만 바꾸면 된다.
TEST_FLAGS=(
  "--dart-define=APP_FLAVOR=dev"
)

# 배포 빌드는 컴파일타임 플래그를 넘기지 않는다. 플레이버가 비면 빈 문자열이다 —
# 아무것도 안 하는 것이 곧 안전장치다.
RELEASE_FLAGS=()

# ── 적용 ─────────────────────────────────────────────────────────

strip_dev_keys() {
  local tmp pattern=""
  tmp="$(mktemp)"
  for k in "${DEV_KEYS[@]}"; do
    pattern="${pattern}${pattern:+|}^${k}="
  done
  grep -Ev "$pattern" "$ENV_FILE" > "$tmp" || true
  mv "$tmp" "$ENV_FILE"
}

BUILD_FLAGS=""

case "$MODE" in
  test)
    strip_dev_keys
    for line in "${TEST_ENV[@]}"; do echo "$line" >> "$ENV_FILE"; done
    BUILD_FLAGS="${TEST_FLAGS[*]}"
    echo "✅ 테스트 빌드 프로파일 적용"
    ;;

  release)
    strip_dev_keys
    # 지우기만 하면 Secret에 값이 없을 때 AppConfig 기본값을 타게 된다.
    # 기본값이 바뀌어도 흔들리지 않도록 **false를 명시**한다.
    echo "ELUM_SHOW_DEV_TOOLS=false" >> "$ENV_FILE"
    echo "ELUM_ENABLE_NETWORK_LOG=false" >> "$ENV_FILE"
    echo "ELUM_SKIP_ONBOARDING=false" >> "$ENV_FILE"
    echo "ELUM_USE_MOCK=false" >> "$ENV_FILE"
    BUILD_FLAGS="${RELEASE_FLAGS[*]:-}"
    echo "✅ 배포 빌드 프로파일 적용"
    ;;

  *)
    echo "::error::알 수 없는 모드: $MODE (test 또는 release)" >&2
    exit 2
    ;;
esac

# ── 결과 출력 — 두 층을 함께 보여준다 ──────────────────────────────
echo "── 런타임 스위치 (.env) ──"
for k in "${DEV_KEYS[@]}"; do
  v="$(grep -E "^${k}=" "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"
  case "$k" in
    *TOKEN*) [ -n "$v" ] && v="(설정됨)" || v="(없음)" ;;   # 토큰 값은 찍지 않는다
    *) [ -n "$v" ] || v="(없음)" ;;
  esac
  printf '  %-26s %s\n' "$k" "$v"
done

echo "── 컴파일타임 플래그 (dart-define) ──"
if [ -n "$BUILD_FLAGS" ]; then
  printf '  %s\n' "$BUILD_FLAGS"
else
  printf '  (없음 — 플레이버 없음)\n'
fi

# 워크플로가 빌드 명령에 그대로 붙일 수 있게 내보낸다.
# GITHUB_OUTPUT이 없으면(로컬 실행) 화면 출력만 하고 넘어간다.
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "build_flags=$BUILD_FLAGS" >> "$GITHUB_OUTPUT"
fi

# ── 검증 — 조용히 넘기지 않는다 ────────────────────────────────────
if [ "$MODE" = "release" ]; then
  for k in "${DEV_KEYS[@]}"; do
    if grep -qE "^${k}=true" "$ENV_FILE"; then
      echo "::error::배포 빌드에 개발 키가 켜져 있습니다: $k" >&2
      exit 1
    fi
  done
  for k in ELUM_DEV_ACCESS_TOKEN ELUM_DEV_REFRESH_TOKEN; do
    if grep -qE "^${k}=." "$ENV_FILE"; then
      echo "::error::배포 빌드에 QA 토큰이 남아 있습니다: $k" >&2
      exit 1
    fi
  done
  # 컴파일타임 쪽도 본다. 여기가 뚫리면 .env가 아무리 깨끗해도 개발 빌드가 나간다.
  if printf '%s' "$BUILD_FLAGS" | grep -q "APP_FLAVOR=dev"; then
    echo "::error::배포 빌드에 개발 플레이버(APP_FLAVOR=dev)가 들어갔습니다" >&2
    exit 1
  fi
  echo "✅ 런타임·컴파일타임 양쪽 모두 꺼진 것을 확인했습니다"
fi
