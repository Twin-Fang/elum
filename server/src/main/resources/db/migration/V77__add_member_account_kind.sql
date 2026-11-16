-- 회원 계정 종류 (이슈 #1436). 추가 전용: 기존 컬럼·행은 건드리지 않는다.
--
-- account_kind: NORMAL 일반 · INTERNAL 내부(운영자) · TEST 테스트 · STORE_REVIEW 스토어 심사. 관리자 숫자는 NORMAL 만 센다
-- account_kind_changed_at / account_kind_changed_by: 마지막으로 종류를 바꾼 시각과 관리자. 바꾼 적 없으면 NULL
-- account_kind_reviewed_at: 분류 제안에서 "일반 맞음"으로 확인한 시각. 있으면 제안에 다시 띄우지 않는다
--
-- 운영 회원의 첫 분류는 배포 뒤 관리자 화면에서 손으로 한다 (여기에 회원 id 를 넣지 않는다).
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 양쪽 모두 안전하게 한다.
ALTER TABLE member ADD COLUMN IF NOT EXISTS account_kind VARCHAR(20) NOT NULL DEFAULT 'NORMAL';
ALTER TABLE member ADD COLUMN IF NOT EXISTS account_kind_changed_at TIMESTAMP(6);
ALTER TABLE member ADD COLUMN IF NOT EXISTS account_kind_changed_by VARCHAR(255);
ALTER TABLE member ADD COLUMN IF NOT EXISTS account_kind_reviewed_at TIMESTAMP(6);
