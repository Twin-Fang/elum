package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.thymeleaf.context.Context;

/**
 * API 문서 화면(iframe), 사이드바 메뉴, 로그인 잠김 안내가 실제로 그려지는지 (#870)
 * 식 하나가 틀리면 그 화면은 500 인데 컴파일로는 안 잡힌다.
 */
class AdminApiDocsTemplateTest {

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  @Test
  @DisplayName("API 문서 화면은 관리자 안 Swagger 주소를 iframe 으로 담고 사이드바에서 선택 상태가 된다")
  void rendersApiDocsPageWithIframe() {
    String html = renderer.render("admin/api-docs", Map.of());

    assertThat(html).contains("<iframe", "src=\"/admin/docs/swagger\"");
    assertThat(html).containsPattern("href=\"/admin/api-docs\"[^>]*class=\"active\"");
  }

  @Test
  @DisplayName("로그인 화면은 잠김 파라미터가 있을 때만 안내를 띄운다")
  void rendersLockedNoticeOnlyWhenLocked() {
    String normal = renderer.render("admin/login", loginContextWithParams(null));
    String locked = renderer.render("admin/login", loginContextWithParams("locked"));

    assertThat(normal).doesNotContain("시도가 너무 많아요");
    assertThat(locked).contains("시도가 너무 많아요");
  }

  // 요청 파라미터(param.error, param.logout, param.locked): 없는 키는 null, 있는 키만 값이 있다
  private Context loginContextWithParams(String presentParameter) {
    Map<String, Object> parameters = new HashMap<>();
    for (String name : new String[] {"error", "logout", "locked"}) {
      parameters.put(name, name.equals(presentParameter) ? new String[] {""} : null);
    }
    Context context = new Context();
    context.setVariable("param", parameters);
    return context;
  }
}
