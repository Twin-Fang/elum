package com.chuseok22.elumserver.auth.infrastructure.oauth;

/**
 * 제공자가 확인해 준 사용자 신원.
 *
 * @param providerUserId 제공자 안에서만 유일한 식별자. <b>계정을 찾는 진짜 키</b>다.
 * @param email          없을 수 있다. 카카오는 선택 동의라 안 줄 수 있고,
 *                       애플은 숨기기 기능으로 privaterelay 주소가 온다.
 * @param emailVerified  제공자가 검증했는지. 이것이 false면 계정 매칭에 쓰지 않는다.
 */
public record OAuthUser(
  String providerUserId,
  String email,
  boolean emailVerified
) {

  public boolean hasTrustedEmail() {
    return emailVerified && email != null && !email.isBlank();
  }
}
