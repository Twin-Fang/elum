#!/usr/bin/env bash
#
# E2E 테스트 계정 초기화 — 지정한 계정을 가입 이전 상태로 되돌린다.
#
# 소셜 로그인은 한 번 가입하면 provider + providerUserId로 계정이 붙어버려
# "첫 로그인" 경로(약관 동의 화면)를 다시 탈 수 없다. 재현하려면 계정을 지워야 한다.
#
# 사용법:
#   ./reset_test_account.sh --list                       # 대상 후보 조회 (삭제 없음)
#   ./reset_test_account.sh --provider KAKAO             # 특정 provider 소셜 계정 삭제
#   ./reset_test_account.sh --username e2e1789628331     # username으로 삭제
#   ./reset_test_account.sh --all-social                 # 소셜 계정 전부 삭제
#   환경변수 ELUM_PROFILE=dev 로 개발 DB 대상 (기본 prod)
#
# 안전장치 — 소셜 연동(auth_identity)이 없고 username이 e2e/test로 시작하지도 않는
# 계정은 절대 지우지 않는다. 기존 일반 가입 사용자를 보호한다.
set -euo pipefail

PROFILE="${ELUM_PROFILE:-prod}"
YML="$(cd "$(dirname "$0")/.." && pwd)/src/main/resources/application-${PROFILE}.yml"
[ -f "$YML" ] || { echo "설정 파일이 없습니다: $YML"; exit 1; }

# jdbc:postgresql://host:port/db 에서 접속 정보를 뽑는다
URL=$(grep -m1 "jdbc:postgresql" "$YML" | sed 's|.*jdbc:postgresql://||; s/[[:space:]]*$//')
export PGHOST="${URL%%:*}"
REST="${URL#*:}"
export PGPORT="${REST%%/*}"
export PGDATABASE="${REST#*/}"
export PGUSER=$(grep -A4 "datasource" "$YML" | grep -m1 "username:" | sed 's/.*username: *//' | tr -d "\"' ")
export PGPASSWORD=$(grep -A4 "datasource" "$YML" | grep -m1 "password:" | sed 's/.*password: *//' | tr -d "\"' ")

MODE="" VALUE=""
case "${1:-}" in
  --list)       MODE=list ;;
  --provider)   MODE=provider; VALUE="${2:?provider를 지정하세요 (KAKAO|NAVER|GOOGLE|APPLE)}" ;;
  --username)   MODE=username; VALUE="${2:?username을 지정하세요}" ;;
  --all-social) MODE=all_social ;;
  *) sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

echo "대상 DB: $PGHOST:$PGPORT/$PGDATABASE (profile=$PROFILE)"

if [ "$MODE" = list ]; then
  psql -c "select m.id, m.username, ai.provider, ai.email, m.terms_agreed, m.consented_at, m.created_at
           from member m left join auth_identity ai on ai.member_id = m.id
           where ai.id is not null or m.username ~* '^(e2e|test)'
           order by m.created_at desc;"
  exit 0
fi

# 삭제 대상 id를 먼저 확정한다 — 안전 조건을 여기 한 곳에서만 건다
case "$MODE" in
  provider)   WHERE="ai.provider = '$VALUE'" ;;
  username)   WHERE="m.username = '$VALUE' and (ai.id is not null or m.username ~* '^(e2e|test)')" ;;
  all_social) WHERE="ai.id is not null" ;;
esac

IDS=$(psql -tAc "select m.id from member m left join auth_identity ai on ai.member_id = m.id where $WHERE;")
[ -n "$IDS" ] || { echo "삭제할 계정이 없습니다."; exit 0; }

echo "삭제 대상:"
psql -c "select m.id, m.username, ai.provider, ai.email from member m
         left join auth_identity ai on ai.member_id = m.id where $WHERE;"

IN_LIST=$(echo "$IDS" | sed "s/^/'/; s/$/'/" | paste -sd, -)

# 자식 → 부모 순으로 지운다. 한 트랜잭션이라 중간에 실패하면 전부 롤백된다.
psql -v ON_ERROR_STOP=1 <<SQL
begin;
delete from profile_support_goals where profile_id in (select id from profile where member_id in ($IN_LIST));
delete from routine_step where routine_id in (select id from routine where profile_id in (select id from profile where member_id in ($IN_LIST)));
delete from routine        where profile_id in (select id from profile where member_id in ($IN_LIST));
delete from profile        where member_id in ($IN_LIST);
delete from refresh_token  where member_id in ($IN_LIST);
delete from ai_call_log    where member_id in ($IN_LIST);
delete from auth_identity  where member_id in ($IN_LIST);
delete from member         where id in ($IN_LIST);
commit;
SQL

echo "완료 — 해당 계정으로 다시 로그인하면 첫 로그인 경로(약관 동의)부터 시작합니다."
psql -c "select count(*) as 남은_회원 from member;"
