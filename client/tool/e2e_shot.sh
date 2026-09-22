#!/usr/bin/env bash
#
# 한 플로우를 **iOS·안드로이드 둘 다**에서 돌려 같은 이름으로 캡처한다.
#
#   bash tool/e2e_shot.sh guardian_home          # 둘 다
#   bash tool/e2e_shot.sh guardian_home ios      # 한쪽만
#
# 결과: e2e/shots/<platform>/<flow>.png
#
# ## 왜 러너가 따로 필요한가
#
# * **기기를 고정하지 않으면 Maestro 가 아무거나 고른다.** 맥에 시뮬레이터와
#   에뮬레이터가 같이 떠 있으면 어느 쪽을 잡았는지 모른 채 결과만 본다.
#   `--udid` 를 항상 박는다.
# * **`takeScreenshot` 은 실행한 자리에 안 떨군다.** `~/.maestro/tests/<실행>/
#   <플로우>/takeScreenshot/<이름>.png` 로 들어가고, 그 폴더는 14일 뒤 지워진다.
#   증적으로 쓰려면 레포 안 고정 경로로 **옮겨 와야** 한다.
# * **`--test-output-dir` 를 주면 그 아래로 모인다.** 실행마다 새 폴더가 생기므로
#   플랫폼별 임시 폴더에 받아 파일만 꺼내 온다.
# * 세션을 날리지 않는다 — 소셜 로그인은 자동화할 수 없어서, 한 번 로그인한
#   기기를 계속 쓴다. `clearState` 는 플로우에서 쓰지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLOW="${1:-}"
ONLY="${2:-}"
[ -n "$FLOW" ] || { echo "사용: bash tool/e2e_shot.sh <플로우이름> [ios|android]" >&2; exit 2; }

FLOW_FILE="$ROOT/e2e/flows/$FLOW.yaml"
[ -f "$FLOW_FILE" ] || { echo "플로우가 없다: $FLOW_FILE" >&2; exit 2; }

command -v maestro >/dev/null 2>&1 || export PATH="$PATH:$HOME/.maestro/bin"

ios_udid() {
  xcrun simctl list devices booted -j 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin)
ids=[x["udid"] for devs in d["devices"].values() for x in devs if x.get("state")=="Booted"]
print(ids[0] if ids else "")'
}

android_serial() {
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {print $1; exit}'
}

run_one() {
  local platform="$1" udid="$2"
  [ -n "$udid" ] || { echo "  $platform: 켜진 기기가 없다 — 건너뛴다"; return 0; }
  local out="$ROOT/e2e/shots/$platform"
  local work; work="$(mktemp -d)"
  mkdir -p "$out"

  if ! maestro --udid "$udid" test "$FLOW_FILE" --test-output-dir "$work" > "$work/run.log" 2>&1; then
    echo "  $platform: ❌ 실패"
    sed -n '/FAILED\|Error\|Exception/,$p' "$work/run.log" | head -12 | sed 's/^/      /'
    return 1
  fi

  # takeScreenshot/<이름>.png 를 레포 안으로 옮겨 온다
  local n=0
  while IFS= read -r shot; do
    cp "$shot" "$out/$(basename "$shot")"
    echo "  $platform: $out/$(basename "$shot")"
    n=$((n + 1))
  done < <(find "$work" -path '*/takeScreenshot/*.png' 2>/dev/null)
  rm -rf "$work"

  [ "$n" -gt 0 ] || { echo "  $platform: ❌ 찍힌 것이 없다 — 플로우에 takeScreenshot 이 있는지 본다"; return 1; }
}

echo "▶ $FLOW"
fail=0
[ "$ONLY" = "android" ] || run_one ios "$(ios_udid)" || fail=1
[ "$ONLY" = "ios" ] || run_one android "$(android_serial)" || fail=1
exit $fail
