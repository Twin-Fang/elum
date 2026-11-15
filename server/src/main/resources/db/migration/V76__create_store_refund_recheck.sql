-- 스토어 환불 재확인과 관리자 구매·환불 목록 (이슈 #1428). 추가 전용: 기존 행은 값만 채운다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.

-- 1) 크레딧 구매: 회수한 양(환불 취소 때 그만큼 다시 적립), 회수 계기
--    refund_origin: STORE_NOTIFICATION 스토어 알림, REFUND_RECHECK 매일 환불 재확인, ADMIN 관리자 수동 회수
ALTER TABLE ai_credit_purchase ADD COLUMN IF NOT EXISTS recovered_credits INTEGER NOT NULL DEFAULT 0;
ALTER TABLE ai_credit_purchase ADD COLUMN IF NOT EXISTS refund_origin VARCHAR(30);
-- 관리자 목록: 최근 구매부터, 상태 필터
CREATE INDEX IF NOT EXISTS idx_ai_credit_purchase_created ON ai_credit_purchase (created_at DESC);

-- 2) 구매 확인보다 먼저 온 환불 (모르는 거래): 보류해 두고 구매 확인 때 바로 회수
--    resolution: NULL 대기, APPLIED 구매 확인 때 회수함, REVERSED 확인 전에 환불이 취소됨
CREATE TABLE IF NOT EXISTS ai_credit_refund_hold (
  id             VARCHAR(255) NOT NULL PRIMARY KEY,
  -- APPLE_IAP | GOOGLE_IAP
  store          VARCHAR(20)  NOT NULL,
  -- Apple transactionId · Google orderId
  transaction_id VARCHAR(255) NOT NULL,
  received_at    TIMESTAMP(6) NOT NULL,
  resolution     VARCHAR(20),
  resolved_at    TIMESTAMP(6),
  created_at     TIMESTAMP(6),
  updated_at     TIMESTAMP(6),
  CONSTRAINT uk_ai_credit_refund_hold_transaction UNIQUE (store, transaction_id)
);

-- 3) 환불 재확인 실행 기록: 스토어별 1회 = 1줄 (failure_reason NULL = 끝까지 성공)
--    trigger_type: SCHEDULED 매일 자동, ADMIN 관리자 "지금 확인"
--    voided_count: Google 취소 구매 목록 건수 (Apple 은 0)
--    checked_count: 거래·주문 상태를 물어본 건수, refunded_count: 스토어가 환불로 답한 건수
--    revoked_count: 이번 실행에서 실제로 회수한 구매 수 (크레딧 + 구독)
CREATE TABLE IF NOT EXISTS store_refund_check_run (
  id             VARCHAR(255) NOT NULL PRIMARY KEY,
  store          VARCHAR(20)  NOT NULL,
  trigger_type   VARCHAR(20)  NOT NULL,
  requested_by   VARCHAR(100),
  started_at     TIMESTAMP(6) NOT NULL,
  finished_at    TIMESTAMP(6),
  voided_count   INTEGER      NOT NULL DEFAULT 0,
  checked_count  INTEGER      NOT NULL DEFAULT 0,
  refunded_count INTEGER      NOT NULL DEFAULT 0,
  revoked_count  INTEGER      NOT NULL DEFAULT 0,
  failure_reason VARCHAR(50),
  created_at     TIMESTAMP(6),
  updated_at     TIMESTAMP(6)
);
CREATE INDEX IF NOT EXISTS idx_store_refund_check_run_store_started
  ON store_refund_check_run (store, started_at DESC);
