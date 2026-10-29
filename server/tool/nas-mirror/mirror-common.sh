#!/usr/bin/env bash
# 미러 서버 스크립트 공통: 경로·컨테이너 이름·환경 파일 읽기
# 내 NAS 에서 root 로 실행 (sudo bash <스크립트>)

# 시놀로지 Container Manager 의 docker 는 PATH 에 없다
DOCKER="${DOCKER:-/var/packages/ContainerManager/target/usr/bin/docker}"

# NAS 폴더: server 는 컨테이너 /app (운영 배포 워크플로 MOUNT_DIR 과 같은 경로)
ELUM_ROOT="/volume1/project/elum"
APP_DIR="${ELUM_ROOT}/server"
POSTGRES_DIR="${ELUM_ROOT}/postgres"
MIRROR_DIR="${ELUM_ROOT}/mirror"
DUMP_DIR="${MIRROR_DIR}/dumps"
# 비밀값: DB·Redis 비밀번호, 원본(친구 서버) DB·SSH 접속 정보 (root 만 읽기)
MIRROR_ENV_FILE="${MIRROR_DIR}/mirror.env"

NETWORK_NAME="elum-net"
POSTGRES_CONTAINER="elum-postgres"
REDIS_CONTAINER="elum-redis"
APP_CONTAINER="elum-back-mirror"

# 원본 DB 가 PostgreSQL 17 이라 덤프·복원 도구도 17
POSTGRES_IMAGE="postgres:17"
REDIS_IMAGE="redis:7-alpine"
APP_IMAGE_REPOSITORY="chuseok22/elum-back"

DB_NAME="elum"
DB_USER="elum"
# 호스트 8085 > 컨테이너 8080 (DSM 리버스 프록시가 이 포트를 본다)
APP_HOST_PORT="8085"
# 남길 덤프 개수
DUMP_KEEP_COUNT=5

log() { echo "[nas mirror] $*"; }
fail() { echo "[nas mirror] failed : $*" >&2; exit 1; }

load_mirror_env() {
  [ -f "$MIRROR_ENV_FILE" ] || fail "missing ${MIRROR_ENV_FILE} (see README.md)"
  # shellcheck disable=SC1090
  set -a; . "$MIRROR_ENV_FILE"; set +a
  local required_name
  for required_name in ELUM_DB_PASSWORD ELUM_REDIS_PASSWORD SOURCE_DB_HOST SOURCE_DB_PORT SOURCE_DB_NAME SOURCE_DB_USER SOURCE_DB_PASSWORD; do
    [ -n "${!required_name:-}" ] || fail "${required_name} is empty in ${MIRROR_ENV_FILE}"
  done
}

is_container_running() {
  [ "$("$DOCKER" inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]
}
