package com.chuseok22.elumserver.common.infrastructure.jwt;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.link.core.LinkRole;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

  @Mock
  private TokenAccessValidator tokenAccessValidator;

  @Mock
  private LinkAccessValidator linkAccessValidator;

  /** 목으로는 클레임을 못 믿는다. 실제로 서명한 토큰을 풀게 한다 (AuthServiceTest 와 같은 설정). */
  private final JwtProvider jwt = new JwtProvider(new JwtProperties(
    "elum-test-secret-key-elum-test-secret-key-0123456789", 86_400_000L, 15_552_000_000L, "elum-test"));

  @AfterEach
  void clearContext() {
    SecurityContextHolder.clearContext();
  }

  private Authentication authenticate(String token) throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/routines/today");
    request.addHeader("Authorization", "Bearer " + token);
    new JwtAuthenticationFilter(jwt, tokenAccessValidator, linkAccessValidator)
      .doFilter(request, new MockHttpServletResponse(), new MockFilterChain());
    return SecurityContextHolder.getContext().getAuthentication();
  }

  @Test
  @DisplayName("E39 이룸이 휴대폰 토큰의 연결 ID 를 인증에 싣는다 — 서비스가 그 연결의 이룸이를 찾는다")
  void e39_elumiToken_carriesLinkId() throws Exception {
    when(tokenAccessValidator.isAllowed(eq("m1"), any())).thenReturn(true);
    when(linkAccessValidator.isLinkActive("l1")).thenReturn(true);

    Authentication auth = authenticate(jwt.createAccessToken("m1", "parent1", LinkRole.ELUMI, "l1"));

    assertThat(auth.getName()).isEqualTo("m1");
    assertThat(auth.getDetails()).isEqualTo(new AccessTokenDetails("l1"));
  }

  @Test
  @DisplayName("보호자 토큰에는 연결 ID 가 없다")
  void guardianToken_hasNoLinkId() throws Exception {
    when(tokenAccessValidator.isAllowed(eq("m1"), any())).thenReturn(true);

    Authentication auth = authenticate(jwt.createAccessToken("m1", "parent1"));

    assertThat(auth.getDetails()).isEqualTo(new AccessTokenDetails(null));
  }
}
