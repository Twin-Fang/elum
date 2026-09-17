-- 약관 동의를 항목별로 기록한다.
--
-- 개인정보보호법은 동의를 항목별로 나눠 받도록 한다. 하나로 뭉쳐 받으면 동의가
-- 무효가 될 수 있다. 그래서 컬럼을 따로 둔다.
--
-- 필수 항목은 이용약관·개인정보 수집이용·국외이전·법정대리인 확인 넷이다.
-- 국외이전이 필수인 이유는 일과 카드를 만들 때 마스킹된 텍스트가 Google(미국)로
-- 전달되기 때문이다. 이 동의가 없으면 카드를 만들 수 없다.
--
-- 마케팅은 선택이다. 거부해도 서비스를 쓸 수 있어야 하며, 거부 의사도 기록한다.
--
-- consented_at은 법적 증빙이다. "언제 동의받았는가"를 답하지 못하면 동의 자체를
-- 입증할 수 없다. consent_version은 약관 개정 시 재동의 대상을 가리는 데 쓴다.

ALTER TABLE member ADD COLUMN terms_agreed             BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE member ADD COLUMN privacy_agreed           BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE member ADD COLUMN overseas_transfer_agreed BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE member ADD COLUMN guardian_confirmed       BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE member ADD COLUMN marketing_agreed         BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE member ADD COLUMN consented_at             TIMESTAMP;
ALTER TABLE member ADD COLUMN consent_version          VARCHAR(255);

-- 기존 회원은 동의를 받은 적이 없다. 기본값 FALSE 그대로 두면 다음 로그인에서
-- 동의 화면이 뜬다. 소급해서 TRUE로 채우면 받지 않은 동의를 받은 것으로
-- 꾸미는 셈이라 하지 않는다.
