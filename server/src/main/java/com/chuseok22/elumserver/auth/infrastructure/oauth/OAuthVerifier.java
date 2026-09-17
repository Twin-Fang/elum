package com.chuseok22.elumserver.auth.infrastructure.oauth;

/**
 * 클라이언트가 보낸 제공자 토큰을 검증한다.
 *
 * <p><b>토큰을 그대로 믿으면 안 된다.</b> 누구나 남의 토큰을 우리 서버로 보낼 수 있다.
 * 구현체는 반드시 <i>이 토큰이 우리 앱을 위해 발급된 것인지</i>(카카오·네이버는 앱 ID,
 * 구글·애플은 {@code aud})까지 확인해야 한다. 그 확인을 빠뜨리면 다른 앱에서 받은
 * 토큰으로 우리 계정에 들어올 수 있다.
 */
public interface OAuthVerifier {

  OAuthProvider provider();

  /**
   * @param token 클라이언트가 제공자 SDK로 받은 토큰
   * @return 검증된 신원
   * @throws com.chuseok22.elumserver.common.infrastructure.exception.CustomException
   *         검증 실패 시. 실패 사유를 클라이언트에 자세히 알리지 않는다.
   */
  OAuthUser verify(String token);
}
