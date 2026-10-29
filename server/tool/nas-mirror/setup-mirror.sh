#!/usr/bin/env bash
# 미러 기반 준비 (여러 번 돌려도 같은 결과): 폴더 > 네트워크 > PostgreSQL 17 > Redis > 미러 덮어쓰기 설정
set -euo pipefail
. "$(dirname "$0")/mirror-common.sh"

load_mirror_env

# 폴더 (config 는 미러 전용 설정, data 는 원본에서 동기화)
mkdir -p "${APP_DIR}/config" "${APP_DIR}/data" "${POSTGRES_DIR}" "${DUMP_DIR}"
chmod 700 "${MIRROR_DIR}" "${APP_DIR}/config"

# 네트워크 (DB·Redis 는 호스트 포트 없이 이 안에서만 접근)
"$DOCKER" network inspect "$NETWORK_NAME" >/dev/null 2>&1 || "$DOCKER" network create "$NETWORK_NAME" >/dev/null
log "network ready : ${NETWORK_NAME}"

# PostgreSQL 17
if ! "$DOCKER" inspect "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
  "$DOCKER" run -d --name "$POSTGRES_CONTAINER" --network "$NETWORK_NAME" --restart unless-stopped \
    -e TZ=Asia/Seoul \
    -e POSTGRES_USER="$DB_USER" -e POSTGRES_PASSWORD="$ELUM_DB_PASSWORD" -e POSTGRES_DB="$DB_NAME" \
    -v "${POSTGRES_DIR}:/var/lib/postgresql/data" \
    "$POSTGRES_IMAGE" >/dev/null
fi
is_container_running "$POSTGRES_CONTAINER" || "$DOCKER" start "$POSTGRES_CONTAINER" >/dev/null
log "postgres ready : ${POSTGRES_CONTAINER}"

# Redis (캐시라 영속 저장 안 함)
if ! "$DOCKER" inspect "$REDIS_CONTAINER" >/dev/null 2>&1; then
  "$DOCKER" run -d --name "$REDIS_CONTAINER" --network "$NETWORK_NAME" --restart unless-stopped \
    "$REDIS_IMAGE" redis-server --requirepass "$ELUM_REDIS_PASSWORD" --save "" --appendonly no >/dev/null
fi
is_container_running "$REDIS_CONTAINER" || "$DOCKER" start "$REDIS_CONTAINER" >/dev/null
log "redis ready : ${REDIS_CONTAINER}"

# 미러 덮어쓰기 설정: 이미지 안 운영 설정 위에 이 키만 바꿈 (WORKDIR /app 이라 Spring 이 config/ 를 자동으로 읽음)
# 푸시 끔: 없는 파일 경로 > NoOp 발송기 (빈 값은 이미지 안 기본 키 firebase-adminsdk.json 으로 바뀌어 켜진다)
cat > "${APP_DIR}/config/application-prod.yml" <<YAML
spring:
  datasource:
    url: jdbc:postgresql://${POSTGRES_CONTAINER}:5432/${DB_NAME}
    username: ${DB_USER}
    password: ${ELUM_DB_PASSWORD}
  data:
    redis:
      host: ${REDIS_CONTAINER}
      port: 6379
      password: ${ELUM_REDIS_PASSWORD}

firebase:
  service-account-key-path: /app/config/push-disabled-no-such-key.json
YAML
chmod 600 "${APP_DIR}/config/application-prod.yml"
log "mirror config written : ${APP_DIR}/config/application-prod.yml"
