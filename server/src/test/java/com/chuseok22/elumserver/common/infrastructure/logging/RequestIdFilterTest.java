package com.chuseok22.elumserver.common.infrastructure.logging;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.slf4j.MDC;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

/**
 * 요청 id 필터 (#656)
 * 깨지면 앱 에러 응답의 requestId 로 서버 로그를 못 찾거나, 남의 요청 id·회원 id 가 다음 요청 로그에 섞인다
 */
class RequestIdFilterTest {

  private final RequestIdFilter filter = new RequestIdFilter();

  @Test
  @DisplayName("요청 id 를 만들어 응답 헤더·MDC·에러 응답에 같은 값으로 싣고, 끝나면 요청 id·회원 id 를 MDC 에서 지운다")
  void generatesIdAndClearsMdc() throws Exception {
    MockHttpServletResponse response = new MockHttpServletResponse();
    AtomicReference<String> idInChain = new AtomicReference<>();
    AtomicReference<ErrorResponse> errorInChain = new AtomicReference<>();

    filter.doFilter(new MockHttpServletRequest("GET", "/api/member/me"), response, (req, res) -> {
      idInChain.set(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY));
      // 인증 필터가 넣는 회원 id 흉내
      MDC.put(RequestIdFilter.MDC_MEMBER_ID_KEY, "m1");
      errorInChain.set(new ErrorResponse(ErrorCode.INTERNAL_SERVER_ERROR, "x"));
    });

    String headerId = response.getHeader(RequestIdFilter.REQUEST_ID_HEADER);
    assertThat(headerId).matches("[0-9a-f]{12}");
    assertThat(idInChain.get()).isEqualTo(headerId);
    assertThat(errorInChain.get().requestId()).isEqualTo(headerId);
    assertThat(MDC.get(RequestIdFilter.MDC_REQUEST_ID_KEY)).isNull();
    assertThat(MDC.get(RequestIdFilter.MDC_MEMBER_ID_KEY)).isNull();
  }

  @Test
  @DisplayName("요청 헤더 id 는 영숫자·하이픈 64자 이하만 그대로 쓰고, 줄바꿈·공백·초과 길이는 버리고 새로 만든다")
  void acceptsOnlySafeInboundId() throws Exception {
    assertThat(responseIdFor("app-req-123")).isEqualTo("app-req-123");
    assertThat(responseIdFor("a".repeat(64))).isEqualTo("a".repeat(64));

    for (String unsafe : new String[]{"abc\n2026-10-08T09:00 ERROR fake", "a b", "a".repeat(65), ""}) {
      assertThat(responseIdFor(unsafe)).as("거절: %s", unsafe).matches("[0-9a-f]{12}");
    }
  }

  private String responseIdFor(String inboundId) throws Exception {
    MockHttpServletRequest request = new MockHttpServletRequest("GET", "/api/routines");
    request.addHeader(RequestIdFilter.REQUEST_ID_HEADER, inboundId);
    MockHttpServletResponse response = new MockHttpServletResponse();
    filter.doFilter(request, response, (req, res) -> { });
    return response.getHeader(RequestIdFilter.REQUEST_ID_HEADER);
  }
}
