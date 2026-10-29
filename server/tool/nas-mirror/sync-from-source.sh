#!/usr/bin/env bash
# 원본(친구 서버) > 미러 덮어쓰기: DB 덤프 > 미러 중지 > DB 복원 > 안전 처리 > 음성 경로 비움 > 그림 동기화 > 미러 재기동
# 미러를 아무도 운영으로 쓰지 않는 동안만 쓴다 (미러에 쓴 데이터는 지워진다)
# 사용: sync-from-source.sh [이미지 태그, 기본 main]
set -euo pipefail
. "$(dirname "$0")/mirror-common.sh"

load_mirror_env
image_tag="${1:-main}"
dump_file="${DUMP_DIR}/elum_$(date +%Y%m%d%H%M%S).dump"

# 1) 덤프 (실패하면 복원하지 않고 기존 미러 유지)
log "dump start : ${SOURCE_DB_HOST}:${SOURCE_DB_PORT}/${SOURCE_DB_NAME}"
if ! "$DOCKER" run --rm --network "$NETWORK_NAME" -e PGPASSWORD="$SOURCE_DB_PASSWORD" "$POSTGRES_IMAGE" \
    pg_dump -h "$SOURCE_DB_HOST" -p "$SOURCE_DB_PORT" -U "$SOURCE_DB_USER" -d "$SOURCE_DB_NAME" \
    -Fc --no-owner --no-privileges > "${dump_file}.partial"; then
  rm -f "${dump_file}.partial"
  fail "dump failed, mirror untouched"
fi
mv "${dump_file}.partial" "$dump_file"
chmod 600 "$dump_file"
log "dump done : ${dump_file} ($(du -h "$dump_file" | cut -f1))"

# 2) 미러 중지 (복원 중 접속 차단)
"$DOCKER" rm -f "$APP_CONTAINER" >/dev/null 2>&1 || true

# 3) 복원: DB 새로 만들기 > pg_restore
"$DOCKER" exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d postgres \
  -c "DROP DATABASE IF EXISTS ${DB_NAME} WITH (FORCE);" -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};" >/dev/null
"$DOCKER" exec -i "$POSTGRES_CONTAINER" pg_restore -U "$DB_USER" -d "$DB_NAME" --no-owner --no-privileges --exit-on-error \
  < "$dump_file" || fail "restore failed : ${dump_file}"
log "restore done"

# 4) 안전 처리: 신고 메일 끔 (푸시는 미러 설정에서 끔)
"$DOCKER" exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
  -c "UPDATE system_config SET config_value = 'false' WHERE config_key = 'TALK_REPORT_MAIL_ENABLED';" >/dev/null
log "safety applied : report mail off"

# 5) 음성은 옮기지 않고 다시 만듦: 경로 비움 > RoutineStepSpeechSweeper 가 Supertonic 으로 채움 (2분마다 20건)
"$DOCKER" exec "$POSTGRES_CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" \
  -c "UPDATE routine_step SET speech_path = NULL WHERE speech_path IS NOT NULL;" >/dev/null
log "speech reset : will be regenerated"

# 6) 파일: 원본 SSH 정보가 있을 때만 (그림만, 음성 제외)
if [ -n "${SOURCE_SSH_TARGET:-}" ]; then
  rsync -a --delete --exclude 'routine-speech/' -e "ssh -p ${SOURCE_SSH_PORT:-22} -o StrictHostKeyChecking=accept-new" \
    "${SOURCE_SSH_TARGET}:${SOURCE_DATA_DIR:-/volume1/project/elum/server/data}/" "${APP_DIR}/data/" \
    || fail "file sync failed (db already restored, mirror stopped)"
  log "file sync done"
else
  log "file sync skipped : SOURCE_SSH_TARGET empty"
fi

# 7) 오래된 덤프 정리 (최근 DUMP_KEEP_COUNT 개만)
ls -1t "${DUMP_DIR}"/elum_*.dump 2>/dev/null | tail -n +$((DUMP_KEEP_COUNT + 1)) | xargs -r rm -f

# 8) 미러 재기동
bash "$(dirname "$0")/run-mirror.sh" "$image_tag"
