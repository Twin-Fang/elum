package com.chuseok22.elumserver.talk.infrastructure.web;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * 이전 잠금 중 공유 미리보기 이동 (#1053)
 * 깨지면: 밖에 퍼진 옛 링크가 잠긴 서버의 멈춘 내용을 보여 준다
 */
class MigrationShareRedirectFilterTest {

  private final MigrationLock migrationLock = mock(MigrationLock.class);
  private final MigrationShareRedirectFilter filter = new MigrationShareRedirectFilter(migrationLock);

  private MockHttpServletResponse run(MockHttpServletRequest request, MockFilterChain chain) throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();
    filter.doFilter(request, response, chain);
    return response;
  }

  @Test
  @DisplayName("잠겼고 새 주소가 있으면 같은 경로·쿼리로 302")
  void redirect_lockedWithBase_302() throws Exception {
    when(migrationLock.isLocked()).thenReturn(true);
    when(migrationLock.newServerBaseUrl()).thenReturn(Optional.of("https://api.elum.suhsaechan.kr"));
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/s/abc");
    request.setQueryString("x=1");
    MockFilterChain chain = new MockFilterChain();

    MockHttpServletResponse response = run(request, chain);

    assertThat(response.getStatus()).isEqualTo(302);
    assertThat(response.getHeader("Location")).isEqualTo("https://api.elum.suhsaechan.kr/s/abc?x=1");
    assertThat(chain.getRequest()).isNull();
  }

  @Test
  @DisplayName("잠기지 않았으면 그대로 통과")
  void redirect_unlocked_passes() throws Exception {
    when(migrationLock.isLocked()).thenReturn(false);
    MockFilterChain chain = new MockFilterChain();

    run(new MockHttpServletRequest("GET", "/s/abc"), chain);

    assertThat(chain.getRequest()).isNotNull();
  }

  @Test
  @DisplayName("잠겼어도 새 주소가 없으면 통과")
  void redirect_lockedWithoutBase_passes() throws Exception {
    when(migrationLock.isLocked()).thenReturn(true);
    when(migrationLock.newServerBaseUrl()).thenReturn(Optional.empty());
    MockFilterChain chain = new MockFilterChain();

    run(new MockHttpServletRequest("GET", "/s/abc"), chain);

    assertThat(chain.getRequest()).isNotNull();
  }
}
