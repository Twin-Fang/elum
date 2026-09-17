#!/usr/bin/env bash
#
# 인증 플로우 E2E — 실제 배포된 서버에 요청을 보내 가입부터 세션 회전까지 검증한다.
#
# 단위 테스트는 목(mock)이라 JPQL 오류·트랜잭션 전파 문제를 잡지 못한다.
# 실제로 한 번 터졌던 것들이라 배포 후 이 스크립트로 실측 확인한다.
#
# 사용법: ./e2e_auth_test.sh [베이스URL]
set -uo pipefail

BASE="${1:-https://api.elum.chuseok22.com}"
USER="e2e$(date +%s)"
PASS="Test1234!"
PASS_CNT=0 FAIL_CNT=0

j() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d$1)" 2>/dev/null; }

ok()   { PASS_CNT=$((PASS_CNT+1)); echo "  ✅ $1"; }
bad()  { FAIL_CNT=$((FAIL_CNT+1)); echo "  ❌ $1"; }
check(){ [ "$2" = "$3" ] && ok "$1 ($2)" || bad "$1 — 기대 '$3' 실제 '$2'"; }

echo "대상: $BASE / 계정: $USER"
echo

echo "[1] 회원가입"
CODE=$(curl -s -o /tmp/e2e_signup.json -w "%{http_code}" -X POST "$BASE/api/auth/signup" \
  -H 'Content-Type: application/json' -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}")
check "가입 응답" "$CODE" "201"

echo "[2] 로그인"
curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}" > /tmp/e2e_login.json
AT=$(j "['data']['accessToken']" < /tmp/e2e_login.json)
RT=$(j "['data']['refreshToken']" < /tmp/e2e_login.json)
[ -n "$AT" ] && ok "액세스 토큰 발급" || bad "액세스 토큰 없음"
[ -n "$RT" ] && ok "리프레시 토큰 발급" || bad "리프레시 토큰 없음"

echo "[3] 최초 상태 — 필수 동의 미완료여야 한다"
C=$(curl -s "$BASE/api/member/me" -H "Authorization: Bearer $AT" | j "['data']['requiredConsentsCompleted']")
check "requiredConsentsCompleted" "$C" "False"

echo "[4] 필수 항목 누락 시 거부되어야 한다 (국외 이전 미동의)"
MSG=$(curl -s -X POST "$BASE/api/member/consents" -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -d '{"termsAgreed":true,"privacyAgreed":true,"overseasTransferAgreed":false,"guardianConfirmed":true,"marketingAgreed":false,"consentVersion":"2026-09-17"}' \
  | j "['code']")
check "거부 코드" "$MSG" "INVALID_INPUT_VALUE"

echo "[5] 전체 동의 (마케팅은 선택이므로 false)"
curl -s -X POST "$BASE/api/member/consents" -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -d '{"termsAgreed":true,"privacyAgreed":true,"overseasTransferAgreed":true,"guardianConfirmed":true,"marketingAgreed":false,"consentVersion":"2026-09-17"}' > /tmp/e2e_consent.json
check "필수 동의 완료" "$(j "['data']['requiredCompleted']" < /tmp/e2e_consent.json)" "True"
check "선택 항목 미동의 보존" "$(j "['data']['marketingAgreed']" < /tmp/e2e_consent.json)" "False"

echo "[6] 동의 후 상태 반영"
C=$(curl -s "$BASE/api/member/me" -H "Authorization: Bearer $AT" | j "['data']['requiredConsentsCompleted']")
check "requiredConsentsCompleted" "$C" "True"

echo "[7] 리프레시 — 토큰이 회전되어야 한다"
curl -s -X POST "$BASE/api/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$RT\"}" > /tmp/e2e_refresh.json
RT2=$(j "['data']['refreshToken']" < /tmp/e2e_refresh.json)
AT2=$(j "['data']['accessToken']" < /tmp/e2e_refresh.json)
[ -n "$RT2" ] && [ "$RT2" != "$RT" ] && ok "리프레시 토큰 회전됨" || bad "회전 안 됨"

echo "[8] 구 토큰 재사용 — 탈취로 간주해 거부해야 한다"
R=$(curl -s -X POST "$BASE/api/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$RT\"}" | j "['code']")
check "재사용 탐지" "$R" "REFRESH_TOKEN_REUSED"

echo "[9] 재사용 탐지 후 — 정상 토큰까지 전부 폐기되어야 한다"
# 탐지만 하고 체인을 살려두면 탈취자가 계속 쓸 수 있다. 실제로 이 단계에서 버그를 잡았다.
R=$(curl -s -X POST "$BASE/api/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$RT2\"}" | j "['code']")
[ "$R" != "null" ] && [ -n "$R" ] && ok "체인 전체 폐기됨 ($R)" || bad "체인이 살아있다 — 폐기가 롤백됐을 가능성"

echo
echo "─────────────────────────────"
echo "통과 $PASS_CNT · 실패 $FAIL_CNT"
echo "정리: ./reset_test_account.sh --username $USER"
[ "$FAIL_CNT" -eq 0 ]
