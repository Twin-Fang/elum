package com.chuseok22.elumserver.common.infrastructure.jwt;

import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.link.core.LinkRole;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.util.Date;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class JwtProvider {

  /**
   * 밀리초 단위 발급 시각 클레임 (이슈 #372 D2).
   *
   * <p>표준 {@code iat} 는 초 단위라, 탈퇴·강제 로그아웃과 같은 초에 받은 토큰은 그 전에 받은 토큰과
   * 발급 시각이 똑같이 잘린다. 둘을 가르려면 발급 쪽에 초 아래 자리가 있어야 한다. 서명 안에 들어가므로
   * 바꿀 수 없다. 표준 {@code iat} 는 그대로 둔다 — 다른 도구와 옛 판정이 그 값을 본다.
   */
  static final String ISSUED_AT_MILLIS_CLAIM = "iatMs";

  private final JwtProperties jwtProperties;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public JwtProvider(JwtProperties jwtProperties) {
    this(jwtProperties, Clock.systemDefaultZone());
  }

  // 테스트가 같은 초 안의 발급 순서를 고정할 수 있게 시계를 밖에서 받는다.
  JwtProvider(JwtProperties jwtProperties, Clock clock) {
    this.jwtProperties = jwtProperties;
    this.clock = clock;
  }

  /** 보호자 휴대폰용. 기존 호출부가 그대로 쓴다. */
  public String createAccessToken(String memberId, String username) {
    return createAccessToken(memberId, username, LinkRole.GUARDIAN);
  }

  /**
   * 어느 휴대폰의 토큰인지 함께 담는다 (이슈 #200).
   *
   * <p>이룸이 휴대폰은 보호자 계정에 붙어 있어 memberId가 같다. role이 없으면 토큰만으로는
   * 둘을 구분할 수 없어, 이룸이 휴대폰에서 일과 삭제·회원 탈퇴가 그대로 된다.
   */
  public String createAccessToken(String memberId, String username, LinkRole role) {
    return createAccessToken(memberId, username, role, null);
  }

  /**
   * 이룸이 휴대폰 토큰에는 <b>어느 연결의 것인지</b>를 함께 담는다 (이슈 #200).
   *
   * <p>연결을 끊어도 이미 발급된 액세스 토큰은 만료까지 살아 있다. 이 값이 없으면
   * 요청마다 "아직 유효한 연결인가"를 물을 수가 없어, 잃어버린 휴대폰이 하루 동안
   * 계속 일과를 본다.
   */
  public String createAccessToken(String memberId, String username, LinkRole role, String linkId) {
    Date now = Date.from(clock.instant());
    Date expiry = new Date(now.getTime() + jwtProperties.accessExpMillis());

    var builder = Jwts.builder()
      .subject(memberId)
      .claim("username", username)
      .claim("role", role.name())
      .claim(ISSUED_AT_MILLIS_CLAIM, now.getTime());
    if (linkId != null) {
      builder = builder.claim("linkId", linkId);
    }

    return builder
      .issuer(jwtProperties.issuer())
      .issuedAt(now)
      .expiration(expiry)
      .signWith(signingKey())
      .compact();
  }

  public Claims parseClaims(String token) {
    return Jwts.parser()
      .clock(() -> Date.from(clock.instant()))
      .verifyWith(signingKey())
      .build()
      .parseSignedClaims(token)
      .getPayload();
  }

  /**
   * 토큰 발급 시각. 무효화 기준({@code tokenInvalidBefore})과 견줄 때 쓴다.
   *
   * <p>밀리초 클레임이 없는 토큰(이 수정 전에 발급된 것)은 표준 {@code iat}(초 단위)로 본다.
   * 그러면 같은 초의 새 토큰이 막히는 옛 동작 그대로라 탈퇴 전 토큰이 살아나는 일은 없다.
   * 액세스 토큰은 하루면 만료되므로 옛 토큰은 곧 사라진다.
   */
  public Date issuedAt(Claims claims) {
    if (claims.get(ISSUED_AT_MILLIS_CLAIM) instanceof Number millis) {
      return new Date(millis.longValue());
    }
    return claims.getIssuedAt();
  }

  public boolean isValid(String token) {
    try {
      parseClaims(token);
      return true;
    } catch (JwtException | IllegalArgumentException e) {
      // ExpiredJwtException은 JwtException의 하위 타입이라 별도 catch 불필요
      // (같이 나열하면 멀티캐치 계층 위반으로 컴파일 에러 발생)
      return false;
    }
  }

  private SecretKey signingKey() {
    return Keys.hmacShaKeyFor(jwtProperties.secretKey().getBytes(StandardCharsets.UTF_8));
  }
}
