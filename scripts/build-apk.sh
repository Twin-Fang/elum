#!/usr/bin/env bash
# 제출용·개발용 APK를 각각 빌드한다.
#
#   ./scripts/build-apk.sh submit   # 제출용 (룸룸_이룸_디지털포용.apk)
#   ./scripts/build-apk.sh dev      # 내부 테스트용 (개발자 도구 포함)
#   ./scripts/build-apk.sh both     # 둘 다
#
# 제출용은 --dart-define을 주지 않는다. 그래야 AppConfig.isDevBuild가 false가 되고
# mock·개발자도구·온보딩 건너뛰기가 .env 값과 무관하게 전부 꺼진다. (이슈 #130)

set -euo pipefail

MODE="${1:-both}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT="$ROOT/client"
OUT="$ROOT/build-output"
SUBMIT_NAME="룸룸_이룸_디지털포용.apk"   # 대회 규칙: 팀이름_개발물이름_분야.apk

mkdir -p "$OUT"
cd "$CLIENT"

build_submit() {
  echo "▶ 제출용 APK 빌드 (개발 플래그 전부 차단)"
  flutter build apk --release
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT/$SUBMIT_NAME"
  echo "  → $OUT/$SUBMIT_NAME"
}

build_dev() {
  echo "▶ 개발용 APK 빌드 (개발자 도구 사용 가능)"
  flutter build apk --release --dart-define=ELUM_BUILD=dev
  cp build/app/outputs/flutter-apk/app-release.apk "$OUT/elum-dev.apk"
  echo "  → $OUT/elum-dev.apk"
}

case "$MODE" in
  submit) build_submit ;;
  dev)    build_dev ;;
  both)   build_submit; build_dev ;;
  *)      echo "사용법: $0 [submit|dev|both]"; exit 1 ;;
esac

echo
echo "빌드 완료. 제출 전 실기기에서 아래를 확인한다."
echo "  1. 앱이 설치되고 첫 화면이 뜨는가"
echo "  2. 일과를 만들면 실제 서버로 가는가 (mock 데이터가 아닌가)"
echo "  3. 개발자 도구 플로팅 버튼이 보이지 않는가"
echo "  4. 온보딩이 정상적으로 나오는가"
