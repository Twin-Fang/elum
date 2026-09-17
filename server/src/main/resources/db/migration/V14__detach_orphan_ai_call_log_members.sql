-- 탈퇴한 회원의 식별자가 AI 호출 기록에 남아 있던 것을 떼어낸다 (이슈 #191).
--
-- ai_call_log.member_id 에는 외래키가 없어 회원을 지워도 DB가 대신 비워 주지 않는다.
-- 탈퇴 코드에서도 빠져 있어 참조가 끊긴 행이 쌓였다.
--
-- 행은 지우지 않는다 — 이 표는 운영 지표(호출량·비용)를 보는 용도라 지우면 과거 집계가
-- 줄어든다. 식별자만 비우면 집계는 유지되고 누가 썼는지는 남지 않는다.
update ai_call_log
   set member_id = null
 where member_id is not null
   and not exists (select 1 from member m where m.id = ai_call_log.member_id);
