-- 보호자가 정한 보상(강화물).
-- 2026-09-13 서울 ABA연구소 자문: 행동 단계만 제공해서는 수행 동기가 생기지 않는다.
-- 앱이 보상을 정하지 않는다 — 보호자가 정하고, 앱은 상기시킨다.
ALTER TABLE routine ADD COLUMN reward_text VARCHAR(100);

-- 프리셋 키(SNACK/VIDEO/PLAY/WALK). 직접 입력이면 NULL.
-- 아동 화면에 그림을 띄우려면 키가 필요하다 — 자유 텍스트만으로는
-- 글자를 못 읽는 사용자에게 의미가 없다.
ALTER TABLE routine ADD COLUMN reward_preset_key VARCHAR(30);
