package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineStatusCounts;
import com.chuseok22.elumserver.admin.application.dto.response.DashboardErrorsView;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.AiCallStats;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 서버 로그 화면과 대시보드 오류 카드가 실제로 그려지는지.
 * 식 하나가 틀리면 그 화면은 500 인데 컴파일로는 안 잡힌다. 템플릿 엔진만으로 그려 본다.
 */
class AdminLogTemplateTest {

  private SpringTemplateEngine engine;

  @BeforeEach
  void setUp() {
    ClassLoaderTemplateResolver resolver = new ClassLoaderTemplateResolver();
    resolver.setPrefix("templates/");
    resolver.setSuffix(".html");
    resolver.setTemplateMode(TemplateMode.HTML);
    resolver.setCharacterEncoding("UTF-8");
    engine = new SpringTemplateEngine();
    engine.setTemplateResolver(resolver);
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
  }

  @Test
  @DisplayName("서버 로그 화면은 탭 다섯 개와 사이드바 오류 배지 자리를 그린다")
  void rendersLogsPage() {
    String html = engine.process("admin/logs", new Context());

    assertThat(html).contains("data-tab=\"live\"", "data-tab=\"files\"", "data-tab=\"search\"",
      "data-tab=\"deploys\"", "data-tab=\"levels\"", "data-log-error-badge");
  }

  @Test
  @DisplayName("대시보드 오류 카드 — 오류가 있을 때와 없을 때 둘 다 그린다")
  void rendersDashboardErrorCard() {
    String withErrors = engine.process("admin/dashboard", dashboard(new DashboardErrorsView(3, "10/08 09:12",
      List.of(new DashboardErrorsView.Item("10/08 10:01:02", "c.c.e.RoutineService", "일과 생성 실패")))));
    String empty = engine.process("admin/dashboard", dashboard(new DashboardErrorsView(0, "10/08 09:12", List.of())));

    assertThat(withErrors).contains("3건", "일과 생성 실패", "집계 시작 10/08 09:12", "badge-error");
    assertThat(empty).contains("0건", "최근 오류가 없어요");
  }

  private Context dashboard(DashboardErrorsView errors) {
    Map<String, Object> variables = new HashMap<>();
    variables.put("memberCount", 10L);
    variables.put("routineStats", new AdminRoutineStatusCounts(5, 1, 2, 2));
    variables.put("todayAiStats", new AiCallStats() {
      public long getTotalCount() { return 4; }
      public long getSuccessCount() { return 4; }
      public double getAvgLatencyMs() { return 100; }
      public long getTotalTokens() { return 1234; }
      public double getTotalCostUsd() { return 0.12; }
    });
    variables.put("activeMemberCount", 3L);
    variables.put("suspendedMemberCount", 0L);
    variables.put("recentErrors", errors);
    Context context = new Context();
    context.setVariables(variables);
    return context;
  }
}
