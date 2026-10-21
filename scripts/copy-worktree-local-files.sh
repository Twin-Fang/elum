#!/usr/bin/env bash
# worktree 에 커밋되지 않는 로컬 전용 파일(환경값·서명·광고 ID)을 메인 작업 폴더에서 복사
#
# 사용: scripts/copy-worktree-local-files.sh            (worktree 안에서 실행, 이미 있는 파일은 덮지 않음)
#       scripts/copy-worktree-local-files.sh --check    (복사 없이 빠진 파일만 알림)
#
# (Firebase 설정 파일은 이 레포에서 로컬로 쓰지 않는다 — CI 가 만든다)
# 빠지면 생기는 일: .env 없음 > 서버 주소 기본값으로 동작 / Secrets.xcconfig 없음 > iOS 앱이 시작 직후 꺼짐
# (GADInvalidInitializationException) / key.properties·key.jks 없음 > Android 릴리스 서명 실패
set -euo pipefail

# 복사 대상 (저장소 루트 기준). 새 로컬 전용 파일이 생기면 여기에 한 줄 더한다.
LOCAL_FILES=(
  "client/.env"                              # 서버 주소·소셜 로그인 키·광고 ID (ELUM_*)
  "client/ios/Flutter/Secrets.xcconfig"      # iOS AdMob 앱 ID 등 (Info.plist 가 읽음)
  "client/android/key.properties"            # Android 서명 설정
  "client/android/app/keystore/key.jks"      # Android 서명 키
  "server/src/main/resources/application-dev.yml"  # 서버 개발 설정
  "server/src/main/resources/application-prod.yml" # 서버 운영 설정
  "server/src/main/resources/firebase-adminsdk.json"   # FCM 서비스 계정 키 (없으면 푸시만 꺼짐)
  "client/android/app/google-services.json"            # Firebase Android 설정
  "client/ios/Runner/GoogleService-Info.plist"         # Firebase iOS 설정 (없으면 시작 시 Firebase 초기화 실패)
)

# 로컬 빌드 보조 (없어도 되지만 있으면 같이 복사): Xcode 26 미만 connectivity_plus 우회
OPTIONAL_FILES=(
  "client/pubspec_overrides.yaml"
)

is_check_only=false
[ "${1:-}" = "--check" ] && is_check_only=true

here="$(git rev-parse --show-toplevel)"
# 메인 작업 폴더 = 공통 .git 이 있는 곳 (worktree 에서는 .git 이 파일이라 common-dir 로 찾는다)
main="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"

if [ "$here" = "$main" ]; then
  echo "메인 작업 폴더입니다. worktree 안에서 실행하세요." >&2
  exit 1
fi

missing_in_main=()
for rel in "${LOCAL_FILES[@]}" "${OPTIONAL_FILES[@]}"; do
  src="$main/$rel"
  dst="$here/$rel"
  if [ ! -f "$src" ]; then
    # 메인에도 없으면 원본 자체가 없는 것이다 (선택 파일이면 조용히 넘어간다)
    case " ${OPTIONAL_FILES[*]} " in *" $rel "*) ;; *) missing_in_main+=("$rel") ;; esac
    continue
  fi
  if [ -f "$dst" ]; then
    echo "있음      $rel"
  elif $is_check_only; then
    echo "빠짐      $rel"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    # 서명 키·환경값은 본인만 읽게 한다
    chmod 600 "$dst"
    echo "복사함    $rel"
  fi
done

for rel in "${missing_in_main[@]:-}"; do
  [ -n "$rel" ] && echo "원본없음  $rel  (메인 작업 폴더에도 없다 — 받아 와야 한다)"
done
