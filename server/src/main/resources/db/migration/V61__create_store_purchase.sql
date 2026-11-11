-- 스토어 구독 결제 (이슈 #1071). 추가 전용: 기존 표는 건드리지 않는다.
--
-- store_purchase: 스토어 구독 1건 = 1줄. 지금 상태(만료일·자동 갱신·유예·환불)와 어느 회원에 묶였는지.
--   purchase_key: App Store 는 originalTransactionId, Google Play 는 purchaseToken
--   member_id 는 외래키를 걸지 않는다 — 알림이 먼저 와서 아직 묶이지 않은 구매(null)도 받아 두고,
--   탈퇴 계정의 구매는 다른 계정이 복원할 때 다시 묶는다.
-- store_purchase_event: 검증 요청·스토어 알림 1건 = 1줄 (관리자 회원 상세의 거래 이력, 알림 중복 차단).
--   원문(JWS·토큰 전체)은 남기지 않는다. 구매 키·거래 id 와 결과만.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS 로 쓴다.
CREATE TABLE IF NOT EXISTS store_purchase (
  id                      VARCHAR(255)  NOT NULL PRIMARY KEY,
  -- APPLE_IAP, GOOGLE_IAP
  store                   VARCHAR(30)   NOT NULL,
  purchase_key            VARCHAR(1024) NOT NULL,
  member_id               VARCHAR(255),
  product_id              VARCHAR(255),
  -- PRODUCTION, SANDBOX (Google 테스트 구매 포함)
  environment             VARCHAR(30)   NOT NULL,
  -- ACTIVE, IN_GRACE_PERIOD, BILLING_RETRY, PAUSED, PENDING, EXPIRED, REVOKED
  state                   VARCHAR(30)   NOT NULL,
  expires_at              TIMESTAMP,
  grace_period_expires_at TIMESTAMP,
  -- 자동 갱신 켜짐 여부. 모르면 null (App Store 갱신 정보 없이 검증한 경우)
  will_auto_renew         BOOLEAN,
  revoked_at              TIMESTAMP,
  latest_transaction_id   VARCHAR(255),
  -- Google 업그레이드·재구독 때 이전 purchaseToken
  linked_purchase_key     VARCHAR(1024),
  -- 이 상태를 스토어가 서명·조회한 시각. 더 오래된 알림·영수증이 새 상태를 덮지 않게 비교한다
  store_signed_at         TIMESTAMP,
  -- Google 구매 확인(acknowledge) 완료 여부. App Store 는 늘 true
  is_acknowledged         BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at              TIMESTAMP,
  updated_at              TIMESTAMP,
  CONSTRAINT uk_store_purchase_store_key UNIQUE (store, purchase_key)
);
-- 회원별 구독 다시 계산 (회원 하나에 스토어 구매 여럿일 수 있음)
CREATE INDEX IF NOT EXISTS idx_store_purchase_member ON store_purchase (member_id);

CREATE TABLE IF NOT EXISTS store_purchase_event (
  id                VARCHAR(255)  NOT NULL PRIMARY KEY,
  store             VARCHAR(30)   NOT NULL,
  purchase_key      VARCHAR(1024),
  member_id         VARCHAR(255),
  -- CLIENT_VERIFY: 앱 검증 요청, STORE_NOTIFICATION: 스토어 알림
  trigger_type      VARCHAR(30)   NOT NULL,
  -- 알림 종류 (예: DID_RENEW.BILLING_RECOVERY, SUBSCRIPTION_RENEWED) 또는 VERIFY
  event_type        VARCHAR(100)  NOT NULL,
  -- 알림 id (App Store notificationUUID, Pub/Sub messageId). 같은 알림 두 번 처리 방지
  external_event_id VARCHAR(255),
  transaction_id    VARCHAR(255),
  -- APPLIED, UNCHANGED, STALE, UNBOUND, REJECTED
  result            VARCHAR(30)   NOT NULL,
  reason            VARCHAR(100),
  state_after       VARCHAR(30),
  expires_at_after  TIMESTAMP,
  occurred_at       TIMESTAMP     NOT NULL,
  created_at        TIMESTAMP,
  updated_at        TIMESTAMP
);
-- 같은 알림은 한 번만 (알림 id 가 있는 줄만)
CREATE UNIQUE INDEX IF NOT EXISTS uk_store_purchase_event_external
  ON store_purchase_event (store, external_event_id) WHERE external_event_id IS NOT NULL;
-- 관리자 회원 상세: 회원별 최신순
CREATE INDEX IF NOT EXISTS idx_store_purchase_event_member_occurred
  ON store_purchase_event (member_id, occurred_at DESC);
