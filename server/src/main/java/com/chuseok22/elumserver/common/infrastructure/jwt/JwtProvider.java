package com.chuseok22.elumserver.common.infrastructure.jwt;

import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
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

  public String createAccessToken(String memberId, String username) {
    Date now = new Date();
    Date expiry = new Date(now.getTime() + jwtProperties.accessExpMillis());

    return Jwts.builder()
      .subject(memberId)
      .claim("username", username)
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
