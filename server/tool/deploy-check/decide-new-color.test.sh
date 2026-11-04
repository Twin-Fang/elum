#!/usr/bin/env bash
# 친구 서버 배포 워크플로 점검: 새 색 고르기 함수 + 전환 검증 규칙 (#1052)
# 사용: bash server/tool/deploy-check/decide-new-color.test.sh (레포 어디서든)
# 운영 서버에 닿지 않는다. 워크플로 파일에서 함수를 뽑아 로컬에서만 돌린다.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/PROJECT-SPRING-CICD.yaml"
FUNCTION_BEGIN_MARK='# >>> decide-new-color'
FUNCTION_END_MARK='# <<< decide-new-color'

pass_count=0
fail_count=0

pass() { pass_count=$((pass_count + 1)); echo "PASS $1"; }
fail() { fail_count=$((fail_count + 1)); echo "FAIL $1 : $2"; }

# 함수 구간 불러오기 (표식이 없으면 결정 시험 전부 실패)
FUNCTION_FILE="$(mktemp)"
trap 'rm -f "${FUNCTION_FILE}"' EXIT
sed -n "/${FUNCTION_BEGIN_MARK}/,/${FUNCTION_END_MARK}/p" "${WORKFLOW}" > "${FUNCTION_FILE}"
# shellcheck disable=SC1090
[ -s "${FUNCTION_FILE}" ] && source "${FUNCTION_FILE}"

# 입력 "conf포트 blue포트 green포트 blue실행 green실행" > 기대 "새포트 새색 옛색 상태"
assert_decision() {
  local name="$1" input="$2" expected="$3" actual
  if ! declare -F decide_new_color >/dev/null; then
    fail "${name}" "decide_new_color 없음 (표식 구간 확인)"
    return
  fi
  # shellcheck disable=SC2086
  actual="$(decide_new_color ${input})"
  if [ "${actual}" = "${expected}" ]; then pass "${name}"; else fail "${name}" "기대 '${expected}' / 실제 '${actual}'"; fi
}

assert_contains() {
  local name="$1" needle="$2"
  if grep -qF -- "${needle}" "${WORKFLOW}"; then pass "${name}"; else fail "${name}" "없음: ${needle}"; fi
}

assert_not_contains() {
  local name="$1" needle="$2"
  if grep -qF -- "${needle}" "${WORKFLOW}"; then fail "${name}" "남아 있음: ${needle}"; else pass "${name}"; fi
}

# 새 색 고르기 6가지
assert_decision normal_blue_active          "8085 8085 8086 1 0" "8086 green blue normal"
assert_decision normal_green_active         "8086 8085 8086 0 1" "8085 blue green normal"
assert_decision normal_both_running         "8085 8085 8086 1 1" "8086 green blue normal"
assert_decision drift_keeps_running_color   "8085 8085 8086 0 1" "8085 blue green drift"   # 2026-11-04 장애
assert_decision drift_reverse               "8086 8085 8086 1 0" "8086 green blue drift"
assert_decision none_running                "8085 8085 8086 0 0" "8085 blue green none-running"

# 실행 중 판정은 멈춘 컨테이너를 빼야 한다 (docker ps -a 금지)
if grep -E 'IS_(BLUE|GREEN)_RUNNING=' "${WORKFLOW}" | grep -q 'docker ps -a'; then
  fail stopped_counts_as_missing "실행 중 판정에 docker ps -a 사용"
elif grep -qE 'IS_BLUE_RUNNING=.*docker ps --format' "${WORKFLOW}"; then
  pass stopped_counts_as_missing
else
  fail stopped_counts_as_missing "실행 중 판정(IS_BLUE_RUNNING=... docker ps --format) 없음"
fi

# 전환 검증: NAS 안 nginx 경로로 확인, 실패를 넘기지 않음
assert_contains     verify_uses_local_nginx_path  '--resolve "${DOMAIN}:443:127.0.0.1"'
assert_not_contains verify_failure_is_not_ignored '도메인 접근 검증 실패: 배포 진행'

echo "결과: PASS ${pass_count} / FAIL ${fail_count}"
[ "${fail_count}" -eq 0 ]
