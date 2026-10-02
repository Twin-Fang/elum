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

class CurrentRegionTest {

  private final RegionFilter filter = new RegionFilter();

  /** 요청을 처리하는 동안(체인 안)의 CurrentRegion. 헤더 null 이면 헤더를 아예 보내지 않는다. */
  private String seenDuring(String header) throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/notices");
    if (header != null) {
      request.addHeader(CurrentRegion.HEADER, header);
    }
    AtomicReference<String> seen = new AtomicReference<>("untouched");
    filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> seen.set(CurrentRegion.get()));
    return seen.get();
  }

  @Test
  @DisplayName("KR 은 KR, JP 는 JP")
  void validCodes_passThrough() throws Exception {
    assertThat(seenDuring("KR")).isEqualTo("KR");
    assertThat(seenDuring("JP")).isEqualTo("JP");
  }

  @Test
  @DisplayName("소문자는 대문자로, 앞뒤 공백은 지운다")
  void normalizes_caseAndWhitespace() throws Exception {
    assertThat(seenDuring("us")).isEqualTo("US");
    assertThat(seenDuring("  es ")).isEqualTo("ES");
  }

  @Test
  @DisplayName("헤더가 없으면 KR — 이미 배포된 앱의 사용자는 모두 한국 사용자")
  void noHeader_isKr() throws Exception {
    assertThat(seenDuring(null)).isEqualTo("KR");
  }

  @Test
  @DisplayName("비었거나 두 글자 영문이 아니면 국가 미상(null) — KR 로 새지 않는다")
  void malformed_isUnknown() throws Exception {
    assertThat(seenDuring("")).isNull();
    assertThat(seenDuring("   ")).isNull();
    assertThat(seenDuring("USA")).isNull();
    assertThat(seenDuring("1")).isNull();
    assertThat(seenDuring("한국")).isNull();
    assertThat(seenDuring("K1")).isNull();
    assertThat(seenDuring("U S")).isNull();
  }

  @Test
  @DisplayName("요청 밖에서 부르면 KR")
  void outsideRequest_isKr() {
    assertThat(CurrentRegion.get()).isEqualTo("KR");
  }

  @Test
  @DisplayName("요청이 끝나면 비운다 — 국가 미상(null)도 다음 요청에 새지 않는다")
  void clearedAfterRequest() throws Exception {
    seenDuring("JP");
    assertThat(CurrentRegion.get()).isEqualTo("KR");

    seenDuring("USA");   // 미상을 저장한 요청
    assertThat(CurrentRegion.get()).isEqualTo("KR");
  }

  @Test
  @DisplayName("체인이 던져도 비운다")
  void clearedWhenChainThrows() {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/notices");
    request.addHeader(CurrentRegion.HEADER, "US");

    assertThatThrownBy(() -> filter.doFilter(request, new MockHttpServletResponse(), (req, res) -> {
      throw new ServletException("boom");
    })).isInstanceOf(ServletException.class);

    assertThat(CurrentRegion.get()).isEqualTo("KR");
  }

  @Test
  @DisplayName("필터는 Spring Security 체인(기본 순서 -100)보다 앞에 있다")
  void runsBeforeSecurityChain() {
    Order order = RegionFilter.class.getAnnotation(Order.class);
    assertThat(order).isNotNull();
    assertThat(order.value()).isLessThan(-100);
  }
}
