#!/usr/bin/env bash
# 원본(친구 서버) > 내 NAS 덮어쓰기: DB 덤프 > 서버 멈춤 > DB 복원 > 이전용 설정 되돌림 > (미러만) 안전 처리 > 파일 > 서버 다시 시작
# 미러를 아무도 운영으로 쓰지 않는 동안만 쓴다 (내 NAS 에 쓴 데이터는 지워진다)
# 사용:
#   sync-from-source.sh [이미지 태그]   # 미러 갱신 (신고 메일 끔, 끝나면 서버 다시 시작)
#   sync-from-source.sh --cutover       # 전환 4단계: 운영 값 그대로, 서버는 멈춘 채로 둠 > verify-consistency.sh
set -euo pipefail
. "$(dirname "$0")/mirror-common.sh"

is_cutover=false
image_tag="main"
for argument in "$@"; do
  case "$argument" in
    --cutover) is_cutover=true ;;
    *) image_tag="$argument" ;;
  esac
done

load_mirror_env
dump_file="${DUMP_DIR}/elum_$(date +%Y%m%d%H%M%S).dump"

# 1) 덤프 (실패하면 복원하지 않고 기존 데이터·서버 유지)
log "dump start : ${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME}"
if ! "$DOCKER" run --rm --network "$NETWORK_NAME" -e PGPASSWORD="$SOURCE_DB_PASSWORD" "$POSTGRES_IMAGE" \
    pg_dump -h "$SOURCE_DB_HOST" -p "$SOURCE_DB_PORT" -U "$SOURCE_DB_USER" -d "$SOURCE_DB_NAME" \
    -Fc --no-owner --no-privileges > "${dump_file}.partial"; then
  rm -f "${dump_file}.partial"
  fail "dump failed, my NAS untouched"
fi
mv "${dump_file}.partial" "$dump_file"
chmod 600 "$dump_file"
log "dump done : ${dump_file} ($(du -h "$dump_file" | cut -f1))"

# 2) 서버 멈춤 (복원 중 접속 차단, 떠 있던 것을 기억해 끝나고 다시 시작)
stopped_containers="$(running_app_containers || true)"
for container_name in $stopped_containers; do
  "$DOCKER" stop -t 40 "$container_name" >/dev/null
  log "stopped : ${container_name}"
done

# 3) 복원: DB 새로 만들기 > pg_restore
"$DOCKER" exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d postgres \
  -c "DROP DATABASE IF EXISTS ${DB_NAME} WITH (FORCE);" -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" >/dev/null
"$DOCKER" exec -i "$POSTGRES_CONTAINER" pg_restore -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges --exit-on-error \
  < "$dump_file" || fail "restore failed : ${dump_file}"
log "restore done"

# 4) 이전용 설정 3개 되돌림 (원본이 켜 둔 이전 잠금·내보내기·새 주소가 내 NAS 까지 따라오지 않게)
# 새 서버 주소: 미러는 비움, 전환은 자기 자신 (비우면 옮겨 온 앱이 저장값을 지우고 옛 서버로 되돌아감)
self_base_url=""
[ "$is_cutover" = "true" ] && self_base_url="$SELF_API_BASE_URL"
"$DOCKER" exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
  -c "UPDATE system_config SET config_value = 'false' WHERE config_key IN ('MIGRATION_LOCK', 'MIGRATION_FILE_EXPORT_ENABLED');" \
  -c "UPDATE system_config SET config_value = '${self_base_url}' WHERE config_key = 'APP_API_BASE_URL';" >/dev/null
log "migration settings reset : lock off, export off, new server url '${self_base_url}'"

# 5) 미러만: 신고 메일 끔 (푸시는 배포 mirror 모드가 끔). 전환은 운영 값 그대로
if [ "$is_cutover" = "false" ]; then
  "$DOCKER" exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    -c "UPDATE system_config SET config_value = 'false' WHERE config_key = 'TALK_REPORT_MAIL_ENABLED';" >/dev/null
  log "mirror safety applied : report mail off"
fi

# 6) 파일: 원본 관리자 API(pull_files.py, 음성 포함) > 원본 SSH(rsync, 그림만) > 없음
is_speech_copied=false
if [ -n "${SOURCE_ADMIN_BASE_URL:-}" ]; then
  APP_DATA_DIR="${APP_DIR}/data" python3 "$(dirname "$0")/pull_files.py" \
    || fail "file pull failed (db already restored, servers stopped)"
  is_speech_copied=true
elif [ -n "${SOURCE_SSH_TARGET:-}" ]; then
  rsync -a --delete --exclude 'routine-speech/' -e "ssh -p ${SOURCE_SSH_PORT:-22} -o StrictHostKeyChecking=accept-new" \
    "${SOURCE_SSH_TARGET}:${SOURCE_DATA_DIR:-/volume1/project/elum/server/data}/" "${APP_DIR}/data/" \
    || fail "file sync failed (db already restored, servers stopped)"
  log "file sync done (rsync, images only)"
else
  log "file sync skipped : SOURCE_ADMIN_BASE_URL and SOURCE_SSH_TARGET empty"
fi

# 7) 음성 파일을 못 받았으면 다시 만듦: 경로 비움 > RoutineStepSpeechSweeper 가 채움 (미러만, 전환은 반드시 복사)
if [ "$is_speech_copied" = "false" ]; then
  [ "$is_cutover" = "true" ] && fail "cutover needs speech files : set SOURCE_ADMIN_* in mirror.env"
  "$DOCKER" exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
    -c "UPDATE routine_step SET speech_path = NULL WHERE speech_path IS NOT NULL;" >/dev/null
  log "speech reset : will be regenerated"
fi

# 8) 오래된 덤프 정리 (최근 DUMP_KEEP_COUNT 개만)
ls -1t "${DUMP_DIR}"/elum_*.dump 2>/dev/null | tail -n +$((DUMP_KEEP_COUNT + 1)) | xargs -r rm -f

# 9) 전환이면 서버를 멈춘 채로 둔다 (떠 있으면 서버가 DB 에 써서 검사가 0 차이에 닿지 못한다)
if [ "$is_cutover" = "true" ]; then
  log "cutover : servers stay stopped (${stopped_containers:-none}). next : verify-consistency.sh"
  exit 0
fi

# 10) 미러: 멈췄던 서버 다시 시작 (없었으면 1단계 미러를 새로 띄움)
if [ -n "$stopped_containers" ]; then
  for container_name in $stopped_containers; do
    "$DOCKER" start "$container_name" >/dev/null
    log "started : ${container_name}"
  done
else
  bash "$(dirname "$0")/run-mirror.sh" "$image_tag"
fi
