#!/usr/bin/env bash
#
# 빌드 종류에 맞게 `.env`의 개발 전용 키를 맞춘다 (이슈 #219).
#
#   apply_build_profile.sh test    <.env 경로>   # QA·테스트 빌드 → 개발 도구 켬
#   apply_build_profile.sh release <.env 경로>   # 사용자에게 나가는 빌드 → 전부 끔
#
# ## 왜 스크립트 하나로 모으나
#
# 빌드 워크플로가 6개다. 각자 `sed`로 키를 만지면, **개발 키가 새로 생길 때마다
# 여섯 군데를 고쳐야 하고 한 군데만 빠뜨려도 조용히 새어 나간다.** 실제로
# `ELUM_ENABLE_NETWORK_LOG`가 그랬다 — 개발 도구는 켰는데 네트워크 로그는 꺼져 있어
# QA가 백엔드 응답을 못 봤다.
#
# 키가 늘면 아래 DEV_KEYS 한 줄만 고친다.
#
# ## `sed -i`를 쓰지 않는다
#
# GNU sed(`-i`)와 BSD sed(`-i ''`) 문법이 달라 Linux 러너와 macOS 러너에서 갈린다.
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

# 개발 전용 키. **여기만 고치면 모든 빌드에 반영된다.**
#   ELUM_SHOW_DEV_TOOLS      디버깅 버튼 (토큰·PIN을 평문으로 보여준다)
#   ELUM_ENABLE_NETWORK_LOG  요청·응답 본문을 로그에 남긴다
#   ELUM_SKIP_ONBOARDING     온보딩 건너뛰기 (PIN 미설정 상태가 된다)
#   ELUM_USE_MOCK            서버 대신 가짜 데이터
#   ELUM_DEV_*_TOKEN         QA 세션 주입용 토큰
DEV_KEYS=(
  ELUM_SHOW_DEV_TOOLS
  ELUM_ENABLE_NETWORK_LOG
  ELUM_SKIP_ONBOARDING
  ELUM_USE_MOCK
  ELUM_DEV_ACCESS_TOKEN
  ELUM_DEV_REFRESH_TOKEN
)

# 테스트 빌드에서 켤 것. 여기 없는 키는 테스트 빌드에서도 꺼진 채로 둔다 —
# `ELUM_USE_MOCK`은 서버 대신 가짜 데이터를 쓰므로 QA가 진짜를 못 본다.
# 토큰은 사람마다 달라 CI가 정할 수 없다.
declare -a TEST_ON=(
  "ELUM_SHOW_DEV_TOOLS=true"
  "ELUM_ENABLE_NETWORK_LOG=true"
)

strip_dev_keys() {
  local tmp
  tmp="$(mktemp)"
  local pattern=""
  for k in "${DEV_KEYS[@]}"; do
    pattern="${pattern}${pattern:+|}^${k}="
  done
  grep -Ev "$pattern" "$ENV_FILE" > "$tmp" || true
  mv "$tmp" "$ENV_FILE"
}

case "$MODE" in
  test)
    strip_dev_keys
    for line in "${TEST_ON[@]}"; do
      echo "$line" >> "$ENV_FILE"
    done
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
    echo "✅ 배포 빌드 프로파일 적용"
    ;;

  *)
    echo "::error::알 수 없는 모드: $MODE (test 또는 release)" >&2
    exit 2
    ;;
esac

# ── 확인 ─────────────────────────────────────────────────────────
# 조용히 넘기지 않는다. 배포 빌드에 개발 도구가 켜진 채 나가면 사고다.
echo "── 적용 결과 ──"
for k in "${DEV_KEYS[@]}"; do
  v="$(grep -E "^${k}=" "$ENV_FILE" | tail -1 | cut -d= -f2- || true)"
  # 토큰 값은 찍지 않는다
  case "$k" in
    *TOKEN*) [ -n "$v" ] && v="(설정됨)" || v="(없음)" ;;
    *) [ -n "$v" ] || v="(없음)" ;;
  esac
  printf '  %-26s %s\n' "$k" "$v"
done

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
  echo "✅ 개발 키가 모두 꺼진 것을 확인했습니다"
fi
