-- 함께하는 사람을 부르는 이름 (다중 보호자 2단계, 이슈 #361).
--
-- member 에는 표시 이름이 없다 — 소셜 가입자의 username 은 "naver_{제공자 ID}" 같은 내부 식별자라 다른 보호자에게
-- 보여 줄 수 없다. 이룸이마다 "엄마 · 아빠 · 센터 선생님"처럼 그 이룸이 안에서 부르는 이름을 관계에 둔다.
-- 본인이 정하고 본인만 바꾼다. 비어 있으면 앱이 "보호자"로 부른다 (기존 관계 행도 비어 있다).
--
-- 추가만 한다 (NULL 허용). 옛 서버 이미지로 되돌려도 이 컬럼을 모른 채 그대로 돈다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 if not exists 로 양쪽 모두 안전하게 한다.
alter table profile_guardian add column if not exists display_name varchar(30);
