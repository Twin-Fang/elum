#!/usr/bin/env bash
# 원본(친구 서버) <-> 내 NAS 정합성 검사 (#1054): Flyway 이력 > 모든 테이블 건수·내용 해시 > 파일 해시
# 차이가 하나라도 있으면 종료 코드 1 (전환 6단계: 0 차이일 때만 진행)
# 사용 (내 NAS 에서 root):
#   verify-consistency.sh               # 전환용: 차이 = 실패
#   verify-consistency.sh --allow-live  # 리허설용: 원본이 살아 있어 생기는 차이는 정보로만
#   verify-consistency.sh --skip-files  # DB 만
#   verify-consistency.sh --status-file <경로>  # 결과를 JSON 으로도 남김 (관리자 "서버 이전" 페이지, #1062)
set -euo pipefail
. "$(dirname "$0")/mirror-common.sh"

is_live_allowed=false
is_files_skipped=false
status_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --allow-live) is_live_allowed=true ;;
    --skip-files) is_files_skipped=true ;;
    --status-file) status_file="${2:-}"; shift ;;
    *) fail "unknown option : $1" ;;
  esac
  shift
done
# 차이 목록 (항목 탭 원본 탭 내 NAS), 결과 JSON 용
differences_file="$(mktemp)"
is_status_written=false

# 결과 JSON: consistent | different | failed. 실패로 끝나도 남긴다 (fail 이 부름)
write_verify_status() {
  [ -n "$status_file" ] || return 0
  is_status_written=true
  VERIFY_RESULT="$1" VERIFY_FILES="${file_result:-skipped}" VERIFY_COUNT="${difference_count:-0}" \
  VERIFY_LIVE="$is_live_allowed" VERIFY_AT="$(date -Iseconds)" VERIFY_DIFFS="$differences_file" write_json_file "$status_file" \
    "{'checkedAt': os.environ['VERIFY_AT'], 'result': os.environ['VERIFY_RESULT'], 'differenceCount': int(os.environ['VERIFY_COUNT']), 'differences': [dict(zip(('item','source','target'), line.rstrip('\\n').split('\\t'))) for line in open(os.environ['VERIFY_DIFFS'])], 'files': os.environ['VERIFY_FILES'], 'isLiveAllowed': os.environ['VERIFY_LIVE'] == 'true'}" || true
}
# 끝날 때: 결과를 못 남기고 끝났으면(질의 실패 등) failed 로 남김 > 임시 파일 정리 (성공·실패 공통)
finish_verify() {
  [ "$is_status_written" = "false" ] && write_verify_status failed
  rm -f "$differences_file"
}
trap finish_verify EXIT

load_mirror_env
is_container_running "$POSTGRES_CONTAINER" || fail "${POSTGRES_CONTAINER} not running"

# 비교에서 빼는 설정 키: 이전용 3개는 복원 직후 내 NAS 에서 기본값으로 되돌린다 (sync-from-source.sh)
EXCLUDED_CONFIG_KEYS_SQL="'MIGRATION_LOCK','MIGRATION_FILE_EXPORT_ENABLED','APP_API_BASE_URL'"
# 비교에서 빼는 관리자 기록: 파일 받기 도구가 목록을 볼 때마다 원본에 남기는 기록 (덤프 뒤에도 생겨 0 차이에 닿지 못함)
EXCLUDED_AUDIT_ACTIONS_SQL="'MIGRATION_FILES_LISTED'"

query_source() {
  "$DOCKER" exec -e PGPASSWORD="$SOURCE_DB_PASSWORD" "$POSTGRES_CONTAINER" \
    psql -h "$SOURCE_DB_HOST" -p "$SOURCE_DB_PORT" -U "$SOURCE_DB_USER" -d "$SOURCE_DB_NAME" -v ON_ERROR_STOP=1 -Atc "$1"
}
query_target() {
  "$DOCKER" exec "$POSTGRES_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -Atc "$1"
}

# 테이블 하나 > "건수 내용해시" (행을 텍스트로 정렬해 md5, 이전용 설정 키는 뺌)
table_fingerprint_sql() {
  local table_name="$1" where_clause=""
  case "$table_name" in
    system_config|system_config_history) where_clause="WHERE t.config_key NOT IN (${EXCLUDED_CONFIG_KEYS_SQL})" ;;
    admin_audit_log) where_clause="WHERE t.action NOT IN (${EXCLUDED_AUDIT_ACTIONS_SQL})" ;;
  esac
  echo "SELECT count(*) || ' ' || md5(coalesce(string_agg(t::text, E'\\n' ORDER BY t::text), '')) FROM public.\"${table_name}\" t ${where_clause}"
}

difference_count=0
report() {
  # 항목 | 원본 | 내 NAS | 결과
  local item="$1" source_value="$2" target_value="$3"
  if [ "$source_value" = "$target_value" ]; then
    printf '  %-34s same\n' "$item"
  else
    difference_count=$((difference_count + 1))
    printf '  %-34s DIFF  source=%s  target=%s\n' "$item" "$source_value" "$target_value"
    printf '%s\t%s\t%s\n' "$item" "$source_value" "$target_value" >> "$differences_file"
  fi
}

# 1) Flyway 이력 (번호·버전·checksum·성공 여부 전부)
log "flyway history"
FLYWAY_SQL="SELECT md5(string_agg(installed_rank || ':' || coalesce(version, '') || ':' || coalesce(checksum::text, '') || ':' || success, ',' ORDER BY installed_rank)) FROM flyway_schema_history"
report "flyway_schema_history" "$(query_source "$FLYWAY_SQL")" "$(query_target "$FLYWAY_SQL")"

# 2) 모든 테이블 (양쪽 목록 합집합, 한쪽에만 있으면 차이)
log "tables"
TABLES_SQL="SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY 1"
source_tables="$(query_source "$TABLES_SQL")"
target_tables="$(query_target "$TABLES_SQL")"
for table_name in $(printf '%s\n%s\n' "$source_tables" "$target_tables" | sort -u); do
  [ "$table_name" = "flyway_schema_history" ] && continue
  # here-string 으로 찾는다 (printf | grep -q 는 pipefail 에서 SIGPIPE 로 가끔 "없음"이 됨)
  if ! grep -qx "$table_name" <<< "$source_tables"; then report "$table_name" "(none)" "exists"; continue; fi
  if ! grep -qx "$table_name" <<< "$target_tables"; then report "$table_name" "exists" "(none)"; continue; fi
  fingerprint_sql="$(table_fingerprint_sql "$table_name")"
  report "$table_name" "$(query_source "$fingerprint_sql")" "$(query_target "$fingerprint_sql")"
done

# 3) 파일 (pull_files.py --verify-only: 원본 목록 해시 <-> 내 NAS 파일)
file_result="skipped"
if [ "$is_files_skipped" = "false" ]; then
  log "files"
  if APP_DATA_DIR="${APP_DIR}/data" python3 "$(dirname "$0")/pull_files.py" --verify-only; then
    file_result="same"
  else
    file_result="DIFF"
    difference_count=$((difference_count + 1))
    printf '%s\t%s\t%s\n' "files" "source" "differs" >> "$differences_file"
  fi
fi

log "result : differences=${difference_count} files=${file_result}"
if [ "$difference_count" -gt 0 ]; then
  write_verify_status different
  if [ "$is_live_allowed" = "true" ]; then
    log "allow-live : differences reported only (source is still serving)"
    exit 0
  fi
  fail "not consistent : ${difference_count} difference(s) — do not switch"
fi
write_verify_status consistent
log "consistent : ok to switch"
