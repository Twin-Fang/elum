-- 보호자 목소리 녹음 열쇠 (이슈 #787). 보호자가 카드마다 녹음하면 이룸이 기기가 기본 음성 대신 이 녹음을 먼저 튼다.
-- guardian_voice_path: 녹음 저장 열쇠 {녹음한 보호자 memberId}/{UUID}.m4a. 녹음이 없으면 NULL.
-- 파일은 카드 그림 저장 폴더 아래 guardian-voice/ 에 있다 (그림처럼 일과 복제는 같은 열쇠를 공유).
--
-- 더하는 것만 한다. 옛 서버 이미지로 되돌려도 이 컬럼을 모른 채 읽고 쓴다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE routine_step ADD COLUMN IF NOT EXISTS guardian_voice_path VARCHAR(255);
