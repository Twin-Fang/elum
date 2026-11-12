package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 알림 보내기 화면이 그려지지 않으면 운영자가 Pro 선물 안내를 보낼 길이 없다 (서버를 띄우지 않고 템플릿 엔진만으로 그림)
class AdminPushTemplateTest {

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  @Test
  @DisplayName("갈 화면 3개 선택지·세션의 먼저 받을 회원·야간 안내가 그려지고, 사이드바에 메뉴가 선택돼 있다")
  void rendersRouteOptionsTestMemberAndQuietHoursNotice() {
    Map<String, Object> variables = new HashMap<>();
    variables.put("testMemberId", "member-me");
    variables.put("maximumRecipientCount", 1000);
    variables.put("titleMaxLength", 50);
    variables.put("bodyMaxLength", 300);
    variables.put("routeOptions", List.of(AdminMessageRoute.values()));
    variables.put("isQuietHours", true);

    String html = renderer.render("admin/push", variables);

    assertThat(html).contains("value=\"home\"", "value=\"plan\"", "value=\"myCredit\"");
    assertThat(html).contains("data-current=\"member-me\"");
    assertThat(html).contains("지금은 밤 9시 ~ 아침 8시라");
    assertThat(html).contains("href=\"/admin/push\" class=\"active\"");
  }
}
