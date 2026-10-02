package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import jakarta.servlet.ServletException;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.annotation.Order;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class AcceptLanguageFilterTest {

  private final AcceptLanguageFilter filter = new AcceptLanguageFilter();

  /** 요청을 처리하는 동안(체인 안)의 CurrentLocale. */
  private AppLocale seenDuring(String header) throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/routines");
    if (header != null) {
      request.addHeader("Accept-Language", header);
    }
    AtomicReference<AppLocale> seen = new AtomicReference<>();
    filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> seen.set(CurrentLocale.get()));
    return seen.get();
  }

  @Test
  @DisplayName("헤더가 없으면 요청 안에서도 KO — 이미 배포된 앱")
  void noHeader_isKo() throws Exception {
    assertThat(seenDuring(null)).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("헤더의 언어가 요청 안에서 보인다")
  void header_isVisibleDuringRequest() throws Exception {
    assertThat(seenDuring("zh-Hans")).isEqualTo(AppLocale.ZH);
    assertThat(seenDuring("ja")).isEqualTo(AppLocale.JA);
    assertThat(seenDuring("ar")).isEqualTo(AppLocale.EN);
    assertThat(seenDuring("en;q=0.1, ja;q=0.9")).isEqualTo(AppLocale.EN);
  }

  @Test
  @DisplayName("요청이 끝나면 비운다 — 풀의 스레드를 재사용해도 다음 요청에 새지 않는다")
  void clearedAfterRequest() throws Exception {
    seenDuring("ja");
    assertThat(CurrentLocale.get()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("체인이 던져도 비운다")
  void clearedWhenChainThrows() {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/routines");
    request.addHeader("Accept-Language", "es");

    assertThatThrownBy(() -> filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> {
      throw new ServletException("boom");
    })).isInstanceOf(ServletException.class);

    assertThat(CurrentLocale.get()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("요청 밖에서는 KO, callAs 는 끝나면 이전 값으로 돌려놓는다")
  void callAs_restores() {
    assertThat(CurrentLocale.get()).isEqualTo(AppLocale.KO);
    String inside = CurrentLocale.callAs(AppLocale.JA, () -> CurrentLocale.get().code());
    assertThat(inside).isEqualTo("ja");
    assertThat(CurrentLocale.get()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("필터는 Spring Security 체인(기본 순서 -100)보다 앞에 있다 — 보안 필터가 내는 오류 응답도 요청 언어를 알아야 한다")
  void runsBeforeSecurityChain() {
    Order order = AcceptLanguageFilter.class.getAnnotation(Order.class);
    assertThat(order).isNotNull();
    assertThat(order.value()).isLessThan(-100);
  }
}
