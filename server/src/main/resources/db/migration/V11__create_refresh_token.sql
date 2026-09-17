-- 리프레시 토큰.
--
-- 보호자는 일과를 한 번 만들면 며칠 앱을 안 열 수 있다. 그때마다 로그인을
-- 요구하면 쓰지 않게 된다. 액세스는 짧게, 리프레시는 길게 두고 쓸 때마다 갱신한다.
--
-- 원문을 저장하지 않는다 — DB가 새도 토큰 자체는 새지 않아야 한다.
-- 갱신할 때마다 새 토큰을 발급하고 쓴 것은 만료시킨다(회전). 이미 쓴 토큰이
-- 다시 오면 탈취로 보고 그 체인 전체를 끊는다.

CREATE TABLE refresh_token (
    id              VARCHAR(255) PRIMARY KEY,
    member_id       VARCHAR(255) NOT NULL,
    token_hash      VARCHAR(64)  NOT NULL UNIQUE,
    device_id       VARCHAR(255),
    expires_at      TIMESTAMP    NOT NULL,
    revoked_at      TIMESTAMP,
    replaced_by_id  VARCHAR(255),
    last_used_at    TIMESTAMP,
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP
);

CREATE INDEX idx_refresh_token_hash ON refresh_token (token_hash);
CREATE INDEX idx_refresh_token_member ON refresh_token (member_id);
