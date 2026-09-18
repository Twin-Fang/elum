package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 시스템 설정에 담기는 비밀값(외부 API 키 등)을 암호화할 마스터 키.
 *
 * <p><b>이 값만은 DB에 둘 수 없다.</b> 암호문과 그것을 푸는 열쇠가 같은 곳에 있으면
 * 암호화가 아무 뜻도 없기 때문이다. 그래서 여기 하나만 환경변수로 남긴다.
 *
 * <p>대신 얻는 것은 크다. 제공자 API 키를 하나씩 환경변수로 넣던 것을, 이제 관리자
 * 화면에서 넣을 수 있다 — <b>새 AI 제공자를 붙일 때마다 재배포하지 않아도 된다.</b>
 *
 * <p>환경변수 이름은 {@code ELUM_SECRET_MASTERKEY}다. 값은 아무 긴 문자열이어도 되며
 * 내부에서 해시해 열쇠로 만든다.
 *
 * <p>이 값이 비어 있어도 서버는 정상 기동한다. 비밀값 저장·조회만 되지 않고, 그
 * 키를 쓰는 기능이 "설정 없음"으로 꺼져 있을 뿐이다.
 */
@ConfigurationProperties(prefix = "elum.secret")
public record SecretProperties(String masterKey) {

  public boolean hasMasterKey() {
    return masterKey != null && !masterKey.isBlank();
  }
}
