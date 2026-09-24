package com.chuseok22.elumserver.common.infrastructure.jwt;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.member.application.service.MemberAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Date;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;

/**
 * 탈퇴(또는 강제 로그아웃)와 같은 초 안에 받은 토큰 (이슈 #372 운영 E2E D2).
 *
 * <p>JWT 표준 발급 시각(iat)은 초 단위다. 탈퇴 시각 {@code tokenInvalidBefore} 는 밀리초 이상이라,
 * 12:00:25.366 에 탈퇴하고 12:00:25.9 에 다시 로그인하면 새 토큰의 iat 가 12:00:25.000 으로 잘려
 * 탈퇴 시각보다 앞선 것으로 보이고 401 이 났다.
 *
 * <p>같은 초에 받은 두 토큰(탈퇴 직전 · 되살린 직후)은 iat 가 똑같다. 그러니 기준 쪽 정밀도만 맞춰서는
 * 둘을 가를 수 없다 — 내리면 탈퇴 전 토큰이 살아나고, 올리면 지금처럼 새 토큰이 막힌다. 시계를 고정해
 * 두 토큰을 같은 초 안에 만들고 둘 다 한 번에 본다.
 */
class SameSecondTokenInvalidationTest {

  private static final ZoneId ZONE = ZoneId.systemDefault();
  private static final JwtProperties PROPS = new JwtProperties(
    "elum-test-secret-key-elum-test-secret-key-0123456789", 86_400_000L, 15_552_000_000L, "elum-test");

  // 운영 E2E 재현값: 탈퇴 커밋 12:00:25.366, 같은 초 안의 앞뒤.
  private static final Instant SECOND = LocalDateTime.of(2026, 9, 24, 12, 0, 25).atZone(ZONE).toInstant();
  private static final Instant BEFORE_WITHDRAW = SECOND.plusMillis(100);
  private static final Instant WITHDRAWN_AT = SECOND.plusMillis(366);
  private static final Instant AFTER_REVIVE = SECOND.plusMillis(900);

  private Member member;
  private MemberAccessGuard guard;
  // 요청을 받는 쪽. 만료 판정도 같은 시계로 해야 고정한 날짜의 토큰이 만료로 떨어지지 않는다.
  private JwtProvider server;

  @BeforeEach
  void setUp() {
    MemberRepository memberRepository = mock(MemberRepository.class);
    member = new Member();
    member.setId("m1");
    member.setStatus(MemberStatus.ACTIVE);
    when(memberRepository.findById("m1")).thenReturn(Optional.of(member));
    guard = new MemberAccessGuard(memberRepository);
    server = providerAt(AFTER_REVIVE.plusMillis(50));
  }

  private static JwtProvider providerAt(Instant instant) {
    return new JwtProvider(PROPS, Clock.fixed(instant, ZONE));
  }

  /** 실제 요청 길: 인증 필터를 태워 인증이 세워지는지 본다. 세워지지 않으면 진입점이 401 을 낸다. */
  private boolean allowed(String token) {
    SecurityContextHolder.clearContext();
    try {
      JwtAuthenticationFilter filter = new JwtAuthenticationFilter(server, guard, linkId -> true);
      MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/member/me");
      request.addHeader("Authorization", "Bearer " + token);
      filter.doFilter(request, new MockHttpServletResponse(), new MockFilterChain());
      return SecurityContextHolder.getContext().getAuthentication() != null;
    } catch (Exception e) {
      throw new IllegalStateException(e);
    } finally {
      SecurityContextHolder.clearContext();
    }
  }

  /** 탈퇴 뒤 되살린 상태. 되살리기는 tokenInvalidBefore 를 그대로 둔다 (WithdrawnMemberService#revive). */
  private void withdrawThenRevive() {
    member.setTokenInvalidBefore(LocalDateTime.ofInstant(WITHDRAWN_AT, ZONE));
    member.setStatus(MemberStatus.ACTIVE);
  }

  @Test
  @DisplayName("D2 탈퇴한 같은 초 — 탈퇴 전에 받은 토큰은 막히고, 되살린 뒤 받은 토큰은 통과한다")
  void sameSecond_oldTokenRejected_newTokenAllowed() {
    String beforeWithdraw = providerAt(BEFORE_WITHDRAW).createAccessToken("m1", "parent1");
    withdrawThenRevive();
    String afterRevive = providerAt(AFTER_REVIVE).createAccessToken("m1", "parent1");

    assertThat(allowed(beforeWithdraw)).as("탈퇴 전 토큰은 반드시 막혀야 한다 (S4)").isFalse();
    assertThat(allowed(afterRevive)).as("되살린 뒤 받은 토큰이 401 이면 다시 로그인한 보람이 없다").isTrue();
  }

  @Test
  @DisplayName("D2 표준 iat 는 초 단위라 두 토큰이 똑같다 — 기준 정밀도만 맞춰서는 가를 수 없다")
  void standardIat_isIdenticalWithinSecond() {
    Claims before = server.parseClaims(providerAt(BEFORE_WITHDRAW).createAccessToken("m1", "parent1"));
    Claims after = server.parseClaims(providerAt(AFTER_REVIVE).createAccessToken("m1", "parent1"));

    assertThat(before.getIssuedAt()).isEqualTo(after.getIssuedAt()).isEqualTo(Date.from(SECOND));
    // 정밀한 발급 시각은 둘을 가른다.
    assertThat(server.issuedAt(before)).isEqualTo(Date.from(BEFORE_WITHDRAW));
    assertThat(server.issuedAt(after)).isEqualTo(Date.from(AFTER_REVIVE));
  }

  @Test
  @DisplayName("밀리초 발급 시각이 없는 옛 토큰은 초 단위 iat 로 본다 — 같은 초면 막는 쪽으로 기운다")
  void legacyToken_fallsBackToSecondIat() {
    // 이 수정 전에 발급된 토큰. 표준 iat 만 있다.
    String legacy = Jwts.builder()
      .subject("m1")
      .claim("username", "parent1")
      .claim("role", "GUARDIAN")
      .issuer(PROPS.issuer())
      .issuedAt(Date.from(AFTER_REVIVE))
      .expiration(Date.from(AFTER_REVIVE.plusMillis(PROPS.accessExpMillis())))
      .signWith(Keys.hmacShaKeyFor(PROPS.secretKey().getBytes(StandardCharsets.UTF_8)))
      .compact();
    withdrawThenRevive();

    assertThat(server.issuedAt(server.parseClaims(legacy))).isEqualTo(Date.from(SECOND));
    assertThat(allowed(legacy)).isFalse();
  }

  @Test
  @DisplayName("초가 바뀐 뒤 받은 토큰은 지금처럼 통과한다")
  void nextSecond_allowed() {
    withdrawThenRevive();
    String nextSecond = providerAt(SECOND.plusSeconds(1).plusMillis(10)).createAccessToken("m1", "parent1");

    assertThat(allowed(nextSecond)).isTrue();
  }
}
