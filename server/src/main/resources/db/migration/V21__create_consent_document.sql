-- 약관을 서버가 관리한다 (이슈 #278).
--
-- 지금까지 약관 본문은 앱 코드(consent_documents.dart)에만 있었다. 오타 하나를 고치려
-- 해도 앱을 다시 빌드해 App Store 심사를 통과해야 했고, 며칠이 걸렸다. 게시된
-- 개인정보처리방침(twin-fang.github.io)과 앱 안 문구가 따로 놀아 한쪽만 고치면
-- 심사에서 불일치로 지적받을 위험도 있었다.
--
-- **앱 번들 기본값을 버리지 않는다.** 서버로만 옮기면 네트워크가 없을 때 약관을 읽을
-- 수 없어 가입이 막힌다. 동의는 "읽을 수 있는 상태에서 받아야" 성립하므로,
-- 앱은 캐시 -> 번들 기본값 순으로 떨어지고 서버는 갱신만 담당한다.
--
-- prod는 ddl-auto: validate라 Hibernate가 테이블을 만들지 않으므로 여기서 직접 만든다.
-- 로컬(ddl-auto: update)에서 이미 만들어졌을 수 있어 IF NOT EXISTS로 양쪽 모두 안전하게 한다.

CREATE TABLE IF NOT EXISTS consent_document (
  id           VARCHAR(255) NOT NULL,
  consent_key  VARCHAR(255) NOT NULL,
  version      VARCHAR(255) NOT NULL,
  label        VARCHAR(255) NOT NULL,
  summary      VARCHAR(255) NOT NULL,
  body         TEXT         NOT NULL,
  required     BOOLEAN      NOT NULL,
  published_at TIMESTAMP(6) NOT NULL,
  created_at   TIMESTAMP(6),
  updated_at   TIMESTAMP(6),
  CONSTRAINT pk_consent_document PRIMARY KEY (id),
  CONSTRAINT uk_consent_document_key UNIQUE (consent_key)
);

-- 고치기 직전 스냅샷. append-only로만 쌓인다.
--
-- 약관은 법적 효력이 있는 문서다. 분쟁이 생기면 "그 사람이 동의한 시점의 문구가
-- 무엇이었나"를 답할 수 있어야 하는데, 현재본만 들고 있으면 답할 방법이 없다.
-- changed_by·reason은 스냅샷이 아니라 이 스냅샷을 만들게 한 변경의 기록이다.
CREATE TABLE IF NOT EXISTS consent_document_history (
  id          VARCHAR(255) NOT NULL,
  consent_key VARCHAR(255) NOT NULL,
  version     VARCHAR(255) NOT NULL,
  label       VARCHAR(255) NOT NULL,
  summary     VARCHAR(255) NOT NULL,
  body        TEXT         NOT NULL,
  required    BOOLEAN      NOT NULL,
  changed_by  VARCHAR(255) NOT NULL,
  reason      TEXT         NOT NULL,
  created_at  TIMESTAMP(6),
  updated_at  TIMESTAMP(6),
  CONSTRAINT pk_consent_document_history PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS idx_consent_document_history_key_created
  ON consent_document_history (consent_key, created_at);

-- 본문 자체는 넣지 않는다. 앱 번들과 한 글자도 어긋나면 안 되는 내용이라
-- ConsentDocumentInitializer가 resources/consent/*.txt(앱 dart에서 기계로 떠낸 것)를
-- 읽어 채운다. SQL에 손으로 옮겨 적으면 그 순간부터 두 벌이 갈라진다.
