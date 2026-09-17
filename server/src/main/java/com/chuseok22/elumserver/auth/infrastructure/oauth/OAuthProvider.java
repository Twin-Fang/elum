package com.chuseok22.elumserver.auth.infrastructure.oauth;

/**
 * 지원하는 소셜 로그인 제공자.
 *
 * <p>두 부류로 나뉜다. 카카오·네이버는 액세스 토큰을 받아 제공자 API를 호출해
 * 확인하고, 구글·애플은 ID 토큰(JWT)의 서명을 공개키로 검증한다.
 * {@link OAuthVerifier} 구현이 그 차이를 흡수한다.
 */
public enum OAuthProvider {
  KAKAO,
  NAVER,
  GOOGLE,
  APPLE;

  public static OAuthProvider from(String raw) {
    if (raw == null) {
      throw new IllegalArgumentException("provider가 비어 있습니다");
    }
    return OAuthProvider.valueOf(raw.trim().toUpperCase());
  }
}
