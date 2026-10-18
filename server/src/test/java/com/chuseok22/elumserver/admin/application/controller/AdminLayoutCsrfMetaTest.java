package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminNoticeList;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.security.web.csrf.DefaultCsrfToken;

/**
 * 관리자 공통 골격이 CSRF meta 를 내보내는지 본다 (이슈 #399).
 *
 * <p>프롬프트 화면 스크립트는 첫 줄에서 {@code meta[name="_csrf"]} 를 읽는다. #248 에서 페이지마다
 * 있던 머리 부분을 골격 한 곳으로 옮기며 이 두 줄이 빠져, 스크립트가 멈추고 "미리보기"·"실제로
 * 테스트하기" 버튼이 아무 반응을 하지 않았다. 골격을 쓰는 페이지 하나를 그려 meta 를 확인한다.
 */
class AdminLayoutCsrfMetaTest {

  private String render(Object csrf) {
    AdminListQuery query = AdminListQuery.of(null, Map.of(), null, null, AdminNoticeList.DEFINITION);
    Map<String, Object> variables = new HashMap<>();
    variables.put("notices", new PageImpl<AppNotice>(List.of()));
    variables.put("rows", List.of());
    variables.put("definition", AdminNoticeList.DEFINITION);
    variables.put("query", query);
    variables.put("pagerBaseUrl", "/admin/notices");
    variables.put("hideDays", 7);
    variables.put("previewJson", "{\"hideDays\":7,\"notices\":[]}");
    if (csrf != null) {
      variables.put("_csrf", csrf);
    }
    return new AdminTemplateRenderSupport().render("admin/notices", variables);
  }

  @Test
  @DisplayName("공통 골격이 CSRF 토큰과 헤더 이름을 meta 로 내보낸다 (이슈 #399)")
  void layout_rendersCsrfMeta() {
    String html = render(new DefaultCsrfToken("X-CSRF-TOKEN", "_csrf", "tok-399"));

    assertThat(html).containsPattern("<meta name=\"_csrf\" content=\"tok-399\"");
    assertThat(html).containsPattern("<meta name=\"_csrf_header\" content=\"X-CSRF-TOKEN\"");
  }

  @Test
  @DisplayName("토큰이 없는 렌더(로그인 전·테스트)에서도 골격이 깨지지 않는다")
  void layout_withoutCsrf_stillRenders() {
    assertThat(render(null)).contains("공지 관리");
  }
}
