-- 계정에 연결된 소셜 신원. 한 계정에 카카오·네이버·구글·애플을 모두 붙일 수 있다.
--
-- 계정을 찾는 키는 (provider, provider_user_id)다. 이메일이 아니다.
-- 애플은 "내 이메일 숨기기"로 앱마다 다른 privaterelay 주소를 주고, 카카오는
-- 이메일이 선택 동의라 아예 없을 수 있다. 이메일로 사람을 식별하려 하면
-- 같은 사람이 여러 계정으로 갈라지거나, 남의 계정에 올라타는 경로가 열린다.
--
-- email 컬럼은 안내용이다. 이미 가입된 주소인지 알려 주기 위해 보관할 뿐
-- 로그인 시 계정 조회에는 쓰지 않는다.

CREATE TABLE auth_identity (
    id               VARCHAR(255) PRIMARY KEY,
    member_id        VARCHAR(255) NOT NULL,
    provider         VARCHAR(20)  NOT NULL,
    provider_user_id VARCHAR(255) NOT NULL,
    email            VARCHAR(255),
    email_verified   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMP,
    updated_at       TIMESTAMP,
    CONSTRAINT uk_auth_identity_provider_user UNIQUE (provider, provider_user_id),
    CONSTRAINT fk_auth_identity_member FOREIGN KEY (member_id)
        REFERENCES member (id) ON DELETE CASCADE
);

CREATE INDEX idx_auth_identity_member ON auth_identity (member_id);

-- 같은 이메일이 여러 제공자에 걸쳐 있을 수 있으므로 UNIQUE를 걸지 않는다.
-- 가입 여부 확인용 조회만 빠르면 된다.
CREATE INDEX idx_auth_identity_email ON auth_identity (email);
