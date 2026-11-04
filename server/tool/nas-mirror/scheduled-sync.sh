#!/usr/bin/env bash
# 주기 동기화·관리자 요청 처리 (DSM 작업 스케줄러가 root 로 부름): 멈춤 확인 > 겹침 방지 > 동기화·검사 > 결과 JSON·로그
# 사용:
#   scheduled-sync.sh                 # 30분 작업 elum-mirror-sync: 동기화
#   scheduled-sync.sh --requests-only # 1분 작업 elum-mirror-requests: 관리자 "서버 이전" 페이지 요청이 있을 때만 동기화·검사
# 전환 때는 먼저 멈춘다: 관리자 페이지 [멈춤] 또는 touch /volume1/project/elum/server/migration-sync/SYNC_PAUSED (CUTOVER.md)
set -uo pipefail
. "$(dirname "$0")/mirror-common.sh"

is_requests_only=false
[ "${1:-}" = "--requests-only" ] && is_requests_only=true

# 멈춤 표식 2곳: 관리자 페이지가 만드는 곳, 이전 위치(mirror/ 바로 아래)
SYNC_PAUSED_FILES=("${SYNC_STATE_DIR}/SYNC_PAUSED" "${MIRROR_DIR}/SYNC_PAUSED")
SYNC_REQUEST_FILE="${SYNC_STATE_DIR}/SYNC_REQUESTED"
VERIFY_REQUEST_FILE="${SYNC_STATE_DIR}/VERIFY_REQUESTED"
SYNC_STATUS_FILE="${SYNC_STATE_DIR}/sync-status.json"
VERIFY_STATUS_FILE="${SYNC_STATE_DIR}/verify-status.json"
# 겹쳐 돌지 않게 (동기화·검사 공통 잠금, 앞 회차가 길어지면 이번 회차는 건너뜀)
SYNC_LOCK_FILE="${MIRROR_DIR}/sync.lock"
SYNC_LOG_DIR="${MIRROR_DIR}/logs"
SYNC_LOG_FILE="${SYNC_LOG_DIR}/scheduled-sync.log"
# 로그 파일 최대 크기 (5MB 넘으면 .1 로 한 번 돌림)
SYNC_LOG_MAX_BYTES=5242880
# 결과 JSON 에 담을 이번 실행 마지막 줄 수
STATUS_LOG_TAIL_LINES=15

mkdir -p "$SYNC_LOG_DIR" "$SYNC_STATE_DIR"

is_sync_paused() {
  local paused_file
  for paused_file in "${SYNC_PAUSED_FILES[@]}"; do
    [ -f "$paused_file" ] && return 0
  done
  return 1
}

# 1분 작업: 요청이 없으면 기록도 남기지 않고 끝낸다 (1분마다 로그가 쌓이지 않게)
has_sync_request=false
has_verify_request=false
if [ "$is_requests_only" = "true" ]; then
  [ -f "$SYNC_REQUEST_FILE" ] && has_sync_request=true
  [ -f "$VERIFY_REQUEST_FILE" ] && has_verify_request=true
  [ "$has_sync_request" = "false" ] && [ "$has_verify_request" = "false" ] && exit 0
fi

if [ -f "$SYNC_LOG_FILE" ] && [ "$(stat -c %s "$SYNC_LOG_FILE")" -gt "$SYNC_LOG_MAX_BYTES" ]; then
  mv -f "$SYNC_LOG_FILE" "${SYNC_LOG_FILE}.1"
fi
exec >>"$SYNC_LOG_FILE" 2>&1

exec 9>"$SYNC_LOCK_FILE"
if ! flock -n 9; then
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') skipped : previous run still holds the lock"
  exit 0
fi

# 동기화 1회: 결과 JSON(진행 중 > 끝) + 이번 실행 출력은 로그와 결과 JSON 마지막 줄로
run_sync() {
  local trigger="$1" started_at started_epoch run_output exit_code result message
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') sync (${trigger})"
  if is_sync_paused; then
    # 결과 JSON 은 그대로 둔다 (마지막 실제 동기화 결과가 보이게, 멈춤은 페이지가 표식 파일로 보여 줌)
    log "skipped : paused"
    return 0
  fi
  started_at="$(date -Iseconds)"
  started_epoch="$(date +%s)"
  STATUS_TRIGGER="$trigger" STATUS_STARTED="$started_at" write_json_file "$SYNC_STATUS_FILE" \
    "{'startedAt': os.environ['STATUS_STARTED'], 'finishedAt': None, 'result': 'running', 'durationSeconds': None, 'trigger': os.environ['STATUS_TRIGGER'], 'message': 'sync running', 'logTail': []}" || true

  run_output="$(mktemp)"
  bash "$(dirname "$0")/sync-from-source.sh" > "$run_output" 2>&1
  exit_code=$?
  cat "$run_output"
  if [ "$exit_code" -eq 0 ]; then result="success"; message="sync done"; else result="failed"; message="$(grep -m1 'failed :' "$run_output" || echo "exit ${exit_code}")"; fi
  log "${result} : $(( $(date +%s) - started_epoch ))s"

  STATUS_TRIGGER="$trigger" STATUS_STARTED="$started_at" STATUS_FINISHED="$(date -Iseconds)" \
  STATUS_RESULT="$result" STATUS_MESSAGE="$message" STATUS_DURATION="$(( $(date +%s) - started_epoch ))" \
  STATUS_TAIL="$(tail -n "$STATUS_LOG_TAIL_LINES" "$run_output")" write_json_file "$SYNC_STATUS_FILE" \
    "{'startedAt': os.environ['STATUS_STARTED'], 'finishedAt': os.environ['STATUS_FINISHED'], 'result': os.environ['STATUS_RESULT'], 'durationSeconds': int(os.environ['STATUS_DURATION']), 'trigger': os.environ['STATUS_TRIGGER'], 'message': os.environ['STATUS_MESSAGE'], 'logTail': os.environ['STATUS_TAIL'].splitlines()}" || true
  rm -f "$run_output"
  return "$exit_code"
}

# 정합성 검사 1회 (리허설 기준 --allow-live: 원본이 살아 있어 생기는 차이는 실패가 아님). 결과는 verify-consistency.sh 가 JSON 으로
run_verify() {
  echo "===== $(date '+%Y-%m-%d %H:%M:%S') verify (request)"
  bash "$(dirname "$0")/verify-consistency.sh" --allow-live --status-file "$VERIFY_STATUS_FILE"
}

overall_exit_code=0
if [ "$is_requests_only" = "true" ]; then
  # 요청 파일은 실행 전에 지운다 (실행 중에 다시 누르면 다음 1분 작업이 받음)
  if [ "$has_sync_request" = "true" ]; then
    rm -f "$SYNC_REQUEST_FILE"
    run_sync request || overall_exit_code=1
  fi
  if [ "$has_verify_request" = "true" ]; then
    rm -f "$VERIFY_REQUEST_FILE"
    run_verify || overall_exit_code=1
  fi
else
  run_sync schedule || overall_exit_code=1
fi
exit "$overall_exit_code"
