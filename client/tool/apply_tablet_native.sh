#!/usr/bin/env bash
# 태블릿 네이티브 설정을 로컬에서만 켜고 끈다 (출시 전 시뮬레이터·에뮬레이터 검증용, 커밋하지 않는다)
# 대상 3곳: iOS 기기 family(아이폰 > 유니버설), iPad 방향 키, Android 세로 고정 해제
# 사용: tool/apply_tablet_native.sh apply | revert | status
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
patch="$repo_root/client/tool/tablet_native.patch"
cd "$repo_root"

# 적용돼 있으면 역방향 패치가 깨끗하게 들어간다
is_applied() { git apply --check -R "$patch" 2>/dev/null; }

case "${1:-}" in
  apply)
    if is_applied; then
      echo "이미 적용돼 있다."
    else
      git apply "$patch"
      echo "적용했다: 아이패드 지원, iPad 4방향, Android 방향 해제 (커밋하지 말 것)."
    fi
    ;;
  revert)
    if is_applied; then
      git apply -R "$patch"
      echo "되돌렸다."
    else
      echo "적용된 상태가 아니다."
    fi
    ;;
  status)
    if is_applied; then echo "applied"; else echo "reverted"; fi
    ;;
  *)
    echo "사용: $0 apply | revert | status" >&2
    exit 1
    ;;
esac
