package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.infrastructure.jwt.AccessTokenDetails;
import org.springframework.security.core.Authentication;

/**
 * 누가 불렀고 어느 이룸이를 가리켰는가 (다중 보호자 명세 4-4 · 4-5).
 *
 * <p>예전에는 서비스가 계정 ID 하나만 받았다. 보호자가 이룸이 여럿을 돌보고(헤더), 이룸이 휴대폰은
 * 연결로 이룸이가 정해지면서(연결 ID) 셋이 함께 다녀야 판단자가 한 번에 답할 수 있다.
 *
 * @param memberId  토큰의 계정. 이룸이 휴대폰이면 그 휴대폰을 붙여 준 보호자다
 * @param linkId    이룸이 휴대폰이면 연결 ID, 보호자 휴대폰이면 null
 * @param profileId {@code X-Profile-Id} 헤더. 없으면 null — 가장 먼저 연결된 이룸이를 쓴다
 */
public record Caller(String memberId, String linkId, String profileId) {

  /** 여러 이룸이를 돌보는 보호자가 어느 이룸이인지 짚는 헤더. 없어도 된다 — 지금 앱은 보내지 않는다. */
  public static final String PROFILE_HEADER = "X-Profile-Id";

  /** Swagger 설명. 이룸이 단위 API 가 같은 문장을 쓴다. */
  public static final String PROFILE_HEADER_DESCRIPTION =
    "어느 이룸이인지(이룸이 ID). 보내지 않으면 가장 먼저 연결된 이룸이를 쓴다 — 지금 앱은 보내지 않는다. "
      + "연결되지 않은 이룸이면 403 PROFILE_ACCESS_DENIED, 연결된 이룸이가 없으면 404 PROFILE_NOT_FOUND.";

  public static Caller guardian(String memberId) {
    return new Caller(memberId, null, null);
  }

  public static Caller guardian(String memberId, String profileId) {
    return new Caller(memberId, null, normalize(profileId));
  }

  public static Caller elumi(String memberId, String linkId) {
    return new Caller(memberId, linkId, null);
  }

  public static Caller elumi(String memberId, String linkId, String profileId) {
    return new Caller(memberId, linkId, normalize(profileId));
  }

  /** 일과 ID 로 부르는 API. 이룸이는 일과가 정하므로 헤더를 보지 않는다. */
  public static Caller from(Authentication authentication) {
    return from(authentication, null);
  }

  public static Caller from(Authentication authentication, String profileIdHeader) {
    String linkId = authentication.getDetails() instanceof AccessTokenDetails details ? details.linkId() : null;
    return new Caller(authentication.getName(), linkId, normalize(profileIdHeader));
  }

  /** 이룸이 휴대폰인가. 필터가 역할이 ELUMI 인 토큰에만 연결 ID 를 싣는다. */
  public boolean isElumi() {
    return linkId != null;
  }

  private static String normalize(String raw) {
    return raw == null || raw.isBlank() ? null : raw.trim();
  }
}
