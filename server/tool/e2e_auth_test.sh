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

# 성공 응답은 최상위에 값이 바로 오고, 실패 응답은 errorCode/errorMessage로 온다.
j() { python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('$1',''))" 2>/dev/null; }
err() { python3 -c "import json,sys; print(json.load(sys.stdin).get('errorCode',''))" 2>/dev/null; }

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
AT=$(j accessToken < /tmp/e2e_login.json)
RT=$(j refreshToken < /tmp/e2e_login.json)
[ -n "$AT" ] && ok "액세스 토큰 발급" || bad "액세스 토큰 없음"
[ -n "$RT" ] && ok "리프레시 토큰 발급" || bad "리프레시 토큰 없음"

echo "[3] 최초 상태 — 필수 동의 미완료여야 한다"
C=$(curl -s "$BASE/api/member/me" -H "Authorization: Bearer $AT" | j requiredConsentsCompleted)
check "requiredConsentsCompleted" "$C" "False"

echo "[4] 필수 항목 누락 시 거부되어야 한다 (국외 이전 미동의)"
MSG=$(curl -s -X POST "$BASE/api/member/consents" -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -d '{"termsAgreed":true,"privacyAgreed":true,"overseasTransferAgreed":false,"guardianConfirmed":true,"marketingAgreed":false,"consentVersion":"2026-09-17"}' \
  | err)
check "거부 코드" "$MSG" "INVALID_INPUT_VALUE"

echo "[5] 전체 동의 (마케팅은 선택이므로 false)"
curl -s -X POST "$BASE/api/member/consents" -H "Authorization: Bearer $AT" \
  -H 'Content-Type: application/json' \
  -d '{"termsAgreed":true,"privacyAgreed":true,"overseasTransferAgreed":true,"guardianConfirmed":true,"marketingAgreed":false,"consentVersion":"2026-09-17"}' > /tmp/e2e_consent.json
check "필수 동의 완료" "$(j requiredCompleted < /tmp/e2e_consent.json)" "True"
check "선택 항목 미동의 보존" "$(j marketingAgreed < /tmp/e2e_consent.json)" "False"

echo "[6] 동의 후 상태 반영"
C=$(curl -s "$BASE/api/member/me" -H "Authorization: Bearer $AT" | j requiredConsentsCompleted)
check "requiredConsentsCompleted" "$C" "True"

echo "[7] 리프레시 — 토큰이 회전되어야 한다"
curl -s -X POST "$BASE/api/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$RT\"}" > /tmp/e2e_refresh.json
RT2=$(j refreshToken < /tmp/e2e_refresh.json)
AT2=$(j accessToken < /tmp/e2e_refresh.json)
[ -n "$RT2" ] && [ "$RT2" != "$RT" ] && ok "리프레시 토큰 회전됨" || bad "회전 안 됨"

echo "[8] 구 토큰 재사용 — 탈취로 간주해 거부해야 한다"
R=$(curl -s -X POST "$BASE/api/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$RT\"}" | err)
check "재사용 탐지" "$R" "REFRESH_TOKEN_REUSED"

echo "[9] 재사용 탐지 후 — 정상 토큰까지 전부 폐기되어야 한다"
# 탐지만 하고 체인을 살려두면 탈취자가 계속 쓸 수 있다. 실제로 이 단계에서 버그를 잡았다.
R=$(curl -s -X POST "$BASE/api/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$RT2\"}" | err)
[ -n "$R" ] && ok "체인 전체 폐기됨 ($R)" || bad "체인이 살아있다 — 폐기가 롤백됐을 가능성"

echo
echo "[10] 세션 둘(기기 A·B)과 이룸이 휴대폰 하나를 만든다"
login() { curl -s -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USER\",\"password\":\"$PASS\"}"; }
refresh() { curl -s -X POST "$BASE/api/auth/refresh" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$1\"}"; }
login > /tmp/e2e_a.json; login > /tmp/e2e_b.json
A_AT=$(j accessToken < /tmp/e2e_a.json); A_RT=$(j refreshToken < /tmp/e2e_a.json)
B_RT=$(j refreshToken < /tmp/e2e_b.json)
CODE_JSON=$(curl -s -X POST "$BASE/api/device-links" -H "Authorization: Bearer $A_AT")
LINK_CODE=$(echo "$CODE_JSON" | j code)
curl -s -X POST "$BASE/api/device-links/redeem" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$LINK_CODE\"}" > /tmp/e2e_elumi.json
E_RT=$(j refreshToken < /tmp/e2e_elumi.json)
[ -n "$E_RT" ] && ok "이룸이 휴대폰 연결" || bad "이룸이 휴대폰 연결 실패"

echo "[11] E33 기기 A 로그아웃 — B 와 이룸이 휴대폰은 그대로여야 한다"
curl -s -o /dev/null -X POST "$BASE/api/auth/logout" -H 'Content-Type: application/json' \
  -d "{\"refreshToken\":\"$A_RT\"}"
refresh "$B_RT" > /tmp/e2e_b2.json; B_RT2=$(j refreshToken < /tmp/e2e_b2.json)
[ -n "$B_RT2" ] && ok "B 세션 유지" || bad "B 세션이 끊겼다 — 로그아웃이 계정 전체를 끊는다"
refresh "$E_RT" > /tmp/e2e_e2.json; E_RT2=$(j refreshToken < /tmp/e2e_e2.json)
[ -n "$E_RT2" ] && ok "이룸이 휴대폰 세션 유지" || bad "이룸이 휴대폰이 끊겼다"

echo "[12] E34 B 의 옛 토큰 재사용 — B 는 끊기고 이룸이 휴대폰은 남아야 한다"
R=$(refresh "$B_RT" | err)
check "재사용 탐지" "$R" "REFRESH_TOKEN_REUSED"
R=$(refresh "$B_RT2" | err)
[ -n "$R" ] && ok "B 의 살아 있던 토큰도 끊김 ($R)" || bad "보호자 세션이 살아 있다"
refresh "$E_RT2" > /tmp/e2e_e3.json
[ -n "$(j refreshToken < /tmp/e2e_e3.json)" ] && ok "이룸이 휴대폰은 그대로" || bad "재사용 감지가 이룸이 휴대폰까지 끊었다"

echo "[13] 정리 — 이룸이 휴대폰 연결을 끊는다 (DB 를 직접 건드리지 않는다)"
login > /tmp/e2e_c.json; C_AT=$(j accessToken < /tmp/e2e_c.json)
LINK_ID=$(curl -s "$BASE/api/device-links" -H "Authorization: Bearer $C_AT" \
  | python3 -c "import json,sys; d=json.load(sys.stdin)['devices']; print(d[0]['linkId'] if d else '')")
[ -n "$LINK_ID" ] && curl -s -o /dev/null -X DELETE "$BASE/api/device-links/$LINK_ID" -H "Authorization: Bearer $C_AT"

echo "[14] 정리 — 이 시험 계정을 탈퇴 API 로 지운다 (E37 · DB 를 직접 건드리지 않는다)"
CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE/api/member/me" -H "Authorization: Bearer $C_AT")
check "탈퇴" "$CODE" "204"

echo "─────────────────────────────"
echo "통과 $PASS_CNT · 실패 $FAIL_CNT"
echo "시험 계정은 [14]에서 탈퇴 API 로 지웠다 — 남았으면 ./reset_test_account.sh --username $USER"
[ "$FAIL_CNT" -eq 0 ]
