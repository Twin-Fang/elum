#!/usr/bin/env bash
# 미러 서버 (다시) 띄우기: 이미지 받기 > 기존 컨테이너 제거 > 실행 > /healthz 확인
# 사용: run-mirror.sh [이미지 태그, 기본 main]
set -euo pipefail
. "$(dirname "$0")/mirror-common.sh"

image_tag="${1:-main}"
image="${APP_IMAGE_REPOSITORY}:${image_tag}"
# 헬스체크 최대 대기 (초)
health_wait_seconds=180

is_container_running "$POSTGRES_CONTAINER" || fail "${POSTGRES_CONTAINER} not running (run setup-mirror.sh)"
is_container_running "$REDIS_CONTAINER" || fail "${REDIS_CONTAINER} not running (run setup-mirror.sh)"
[ -f "${APP_DIR}/config/application-prod.yml" ] || fail "missing mirror config (run setup-mirror.sh)"

"$DOCKER" pull "$image" >/dev/null
"$DOCKER" rm -f "$APP_CONTAINER" >/dev/null 2>&1 || true

# ELUM_INSTANCE: 로그 폴더·관리자 화면의 서버 이름 (logback-spring.xml)
"$DOCKER" run -d --name "$APP_CONTAINER" --network "$NETWORK_NAME" --restart unless-stopped \
  -p "${APP_HOST_PORT}:8080" \
  -e TZ=Asia/Seoul \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e ELUM_INSTANCE=mirror \
  -e ELUM_PORT="$APP_HOST_PORT" \
  -v /etc/localtime:/etc/localtime:ro \
  -v "${APP_DIR}:/app" \
  "$image" >/dev/null
log "started : ${APP_CONTAINER} (${image}, port ${APP_HOST_PORT})"

for attempt in $(seq 1 "$health_wait_seconds"); do
  if curl -fsS "http://127.0.0.1:${APP_HOST_PORT}/healthz" >/dev/null 2>&1; then
    log "healthy : attempt ${attempt}"
    # 미러가 실사용자에게 푸시를 보내면 안 됨: 켜져 있으면 바로 중지
    if "$DOCKER" logs "$APP_CONTAINER" 2>&1 | grep -q '\[notification push\] enabled'; then
      "$DOCKER" stop "$APP_CONTAINER" >/dev/null
      fail "push enabled on mirror, stopped ${APP_CONTAINER} (check config/application-prod.yml)"
    fi
    log "push disabled : ok"
    exit 0
  fi
  is_container_running "$APP_CONTAINER" || break
  sleep 1
done

"$DOCKER" logs --tail=200 "$APP_CONTAINER" >&2 || true
fail "health check failed : ${APP_CONTAINER}"
