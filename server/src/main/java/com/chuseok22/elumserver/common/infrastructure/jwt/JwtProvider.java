package com.chuseok22.elumserver.common.infrastructure.jwt;

import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.link.core.LinkRole;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import javax.crypto.SecretKey;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class JwtProvider {

  private final JwtProperties jwtProperties;

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
    Date now = new Date();
    Date expiry = new Date(now.getTime() + jwtProperties.accessExpMillis());

    var builder = Jwts.builder()
      .subject(memberId)
      .claim("username", username)
      .claim("role", role.name());
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
      .verifyWith(signingKey())
      .build()
      .parseSignedClaims(token)
      .getPayload();
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
