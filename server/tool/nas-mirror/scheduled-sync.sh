#!/usr/bin/env bash
# 주기 동기화 (DSM 작업 스케줄러가 30분마다 root 로 부름): 멈춤 표식 확인 > 겹침 방지 > sync-from-source.sh > 로그 보관
# 전환 때는 먼저 멈춤 표식을 만든다: touch /volume1/project/elum/mirror/SYNC_PAUSED (CUTOVER.md)
set -uo pipefail
. "$(dirname "$0")/mirror-common.sh"

# 있으면 건너뜀 (전환·점검 중 덮어쓰기 방지)
SYNC_PAUSED_FILE="${MIRROR_DIR}/SYNC_PAUSED"
# 겹쳐 돌지 않게 (앞 동기화가 30분을 넘기면 이번 회차는 건너뜀)
SYNC_LOCK_FILE="${MIRROR_DIR}/sync.lock"
SYNC_LOG_DIR="${MIRROR_DIR}/logs"
SYNC_LOG_FILE="${SYNC_LOG_DIR}/scheduled-sync.log"
# 로그 파일 최대 크기 (5MB 넘으면 .1 로 한 번 돌림)
SYNC_LOG_MAX_BYTES=5242880

mkdir -p "$SYNC_LOG_DIR"
if [ -f "$SYNC_LOG_FILE" ] && [ "$(stat -c %s "$SYNC_LOG_FILE")" -gt "$SYNC_LOG_MAX_BYTES" ]; then
  mv -f "$SYNC_LOG_FILE" "${SYNC_LOG_FILE}.1"
fi
exec >>"$SYNC_LOG_FILE" 2>&1

echo "===== $(date '+%Y-%m-%d %H:%M:%S') scheduled sync"
if [ -f "$SYNC_PAUSED_FILE" ]; then
  log "skipped : paused (${SYNC_PAUSED_FILE})"
  exit 0
fi

exec 9>"$SYNC_LOCK_FILE"
if ! flock -n 9; then
  log "skipped : previous sync still running"
  exit 0
fi

started_at="$(date +%s)"
if bash "$(dirname "$0")/sync-from-source.sh"; then
  log "scheduled sync done : $(( $(date +%s) - started_at ))s"
else
  log "scheduled sync failed : $(( $(date +%s) - started_at ))s (servers restarted by sync-from-source.sh)"
  exit 1
fi
