#!/usr/bin/env bash
# .env의 소셜 로그인 키를 iOS 빌드 설정으로 옮긴다.
#
# iOS는 URL 스킴과 네이버 SDK 설정을 Info.plist에서 읽는데, 그 값이 빌드 타임에
# 필요해 flutter_dotenv로는 주입할 수 없다. Info.plist에 직접 적으면 시크릿이
# 저장소에 커밋되므로, .env를 읽어 gitignore된 xcconfig로 만든다.
#
# 사용: client 디렉터리에서 `bash tool/gen_ios_secrets.sh`
# CI는 .env를 만든 직후 이 스크립트를 부른다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"
OUT="$ROOT/ios/Flutter/Secrets.xcconfig"

if [ ! -f "$ENV_FILE" ]; then
  echo "[gen_ios_secrets] .env가 없어 빈 설정을 만든다. iOS 소셜 로그인은 동작하지 않는다."
fi

read_env() {
  [ -f "$ENV_FILE" ] || { echo ""; return; }
  # 주석·빈 줄을 건너뛰고 첫 '=' 기준으로 값만 꺼낸다
  grep -E "^$1=" "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r' || true
}

KAKAO_KEY="$(read_env ELUM_KAKAO_NATIVE_APP_KEY)"
NAVER_ID="$(read_env ELUM_NAVER_CLIENT_ID)"
NAVER_SECRET="$(read_env ELUM_NAVER_CLIENT_SECRET)"
NAVER_NAME="$(read_env ELUM_NAVER_CLIENT_NAME)"
GOOGLE_IOS_ID="$(read_env ELUM_GOOGLE_IOS_CLIENT_ID)"

# 구글은 클라이언트 ID를 뒤집은 값을 URL 스킴으로 쓴다.
#   123-abc.apps.googleusercontent.com → com.googleusercontent.apps.123-abc
GOOGLE_SCHEME=""
if [ -n "$GOOGLE_IOS_ID" ]; then
  GOOGLE_SCHEME="com.googleusercontent.apps.${GOOGLE_IOS_ID%%.apps.googleusercontent.com}"
fi

mkdir -p "$(dirname "$OUT")"
cat > "$OUT" <<EOF
// 자동 생성 파일 — 직접 고치지 않는다. tool/gen_ios_secrets.sh가 .env로 만든다.
ELUM_KAKAO_SCHEME=kakao${KAKAO_KEY}
ELUM_NAVER_CLIENT_ID=${NAVER_ID}
ELUM_NAVER_CLIENT_SECRET=${NAVER_SECRET}
ELUM_NAVER_CLIENT_NAME=${NAVER_NAME}
ELUM_GOOGLE_REVERSED_CLIENT_ID=${GOOGLE_SCHEME}
EOF

echo "[gen_ios_secrets] ios/Flutter/Secrets.xcconfig 생성 완료"
