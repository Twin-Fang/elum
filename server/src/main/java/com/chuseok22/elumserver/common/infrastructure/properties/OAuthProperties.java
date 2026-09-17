package com.chuseok22.elumserver.common.infrastructure.properties;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 소셜 로그인 제공자 설정.
 *
 * <p>여기 담긴 앱 식별자(카카오 appId, 구글 clientIds, 애플 bundleIds)는 장식이 아니라
 * <b>검증에 실제로 쓰이는 값</b>이다. 이 값이 비면 "우리 앱을 위해 발급된 토큰인지"를
 * 확인할 수 없어 다른 앱에서 받은 토큰으로도 로그인이 된다. 그래서 각 검증기는
 * 설정이 비어 있으면 통과시키지 않고 실패시킨다.
 */
@ConfigurationProperties(prefix = "oauth")
public record OAuthProperties(
  Kakao kakao,
  Naver naver,
  Google google,
  Apple apple,
  long timeoutMillis
) {

  public OAuthProperties {
    // 제공자 서버가 응답하지 않을 때 로그인 요청 스레드가 무한정 묶이지 않도록 기본값을 둔다.
    if (timeoutMillis <= 0) {
      timeoutMillis = 5000;
    }
    if (kakao == null) {
      kakao = new Kakao(null);
    }
    if (naver == null) {
      naver = new Naver(null, null);
    }
    if (google == null) {
      google = new Google(List.of());
    }
    if (apple == null) {
      apple = new Apple(List.of());
    }
  }

  /** @param appId 카카오 개발자 콘솔의 앱 ID. 토큰 정보 조회 결과와 대조한다. */
  public record Kakao(String appId) {

  }

  /**
   * 네이버는 액세스 토큰이 어느 앱 것인지 알려주는 API가 없다(카카오의 app_id 같은 값이 없다).
   * clientId/clientSecret은 나중에 인가 코드 교환 방식으로 바꿀 때를 위해 받아 둔다.
   */
  public record Naver(String clientId, String clientSecret) {

  }

  /** @param clientIds Android·iOS·Web 클라이언트 ID를 모두 넣는다. ID 토큰의 aud와 대조한다. */
  public record Google(List<String> clientIds) {

    public Google {
      clientIds = clientIds == null ? List.of() : List.copyOf(clientIds);
    }
  }

  /** @param bundleIds 애플 서비스 ID / 앱 번들 ID. ID 토큰의 aud와 대조한다. */
  public record Apple(List<String> bundleIds) {

    public Apple {
      bundleIds = bundleIds == null ? List.of() : List.copyOf(bundleIds);
    }
  }
}
