package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.Highlight;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.PlanRow;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminListRow;
import com.chuseok22.elumserver.admin.application.service.AdminSettingsHistoryService;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.context.support.GenericApplicationContext;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.spring6.expression.ThymeleafEvaluationContext;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 시스템 설정 화면·변경 이력 화면이 실제로 그려지는지: 요약, Free/Pro 비교, 표 행, 이력 없음 문구, 비밀값 가림
 * 스프링 없이 템플릿 엔진만으로 그림 (식 하나가 틀리면 화면이 500 이라 렌더로 잡음)
 */
class AdminSettingsTemplateTest {

  private SpringTemplateEngine engine;
  private GenericApplicationContext applicationContext;

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
    applicationContext = new GenericApplicationContext();
    applicationContext.registerBean("adminDate", AdminDateFormatter.class);
    applicationContext.refresh();
  }

  private String render(String template, Map<String, Object> variables) {
    Context context = new Context();
    context.setVariables(variables);
    context.setVariable(ThymeleafEvaluationContext.THYMELEAF_EVALUATION_CONTEXT_CONTEXT_VARIABLE_NAME,
      new ThymeleafEvaluationContext(applicationContext, null));
    return engine.process(template, context);
  }

  private static SettingRow row(
    String key, String label, boolean isDifferent, boolean isSecret, LocalDateTime changedAt, String reason
  ) {
    return new SettingRow(key, label, "설명 " + label, "PLAN_FREE", "Free 플랜 한도", isSecret ? "SECRET" : "BOOLEAN",
      List.of(), null, null, isSecret ? "" : "true", isSecret ? "설정됨" : "켜짐", "false", isSecret ? "" : "꺼짐",
      isDifferent, isSecret, changedAt != null, changedAt, changedAt == null ? null : "admin", reason);
  }

  private Map<String, Object> settingsModel(List<SettingRow> rows) {
    SettingsOverview overview = new SettingsOverview(1,
      List.of(new Highlight("MAINTENANCE_MODE", "점검 모드", "꺼짐", false, false),
        new Highlight("FREE_ADS_REMOVED", "Free 광고 제거", "켜짐", true, true)),
      List.of(new PlanRow("광고 제거", "FREE_ADS_REMOVED", "켜짐", true, "PRO_ADS_REMOVED", "켜짐", false)));
    Map<String, Object> model = new HashMap<>();
    model.put("rows", rows);
    model.put("today", java.time.LocalDate.of(2026, 10, 18));
    model.put("overview", overview);
    model.put("groupLabelByName", new LinkedHashMap<>(Map.of("PLAN_FREE", "Free 플랜 한도")));
    model.put("imageProviders", List.of());
    model.put("textProviders", List.of());
    return model;
  }

  @Test
  @DisplayName("설정 화면: 요약·Free/Pro 비교·표 열·칩·검색이 그려지고 기본값과 다른 값이 강조된다")
  void settingsPage_rendersSummaryComparisonAndTable() {
    String html = render("admin/settings", settingsModel(List.of(
      row("FREE_ADS_REMOVED", "광고 제거", true, false, LocalDateTime.of(2026, 10, 18, 9, 5), "실증"))));

    assertThat(html).contains("data-settings-summary").contains("개 보기");
    assertThat(html).contains("지금 적용 중").contains("Free / Pro 비교").contains("data-plan-comparison");
    assertThat(html).contains("점검 모드").contains("badge-success");
    assertThat(html).as("기본값과 다른 Free 값은 노란 배지").contains("badge badge-warning");
    assertThat(html).contains("설정").contains("현재 값").contains("기본값").contains("마지막 변경");
    assertThat(html).contains("data-chip=\"different\"").contains("data-chip=\"today\"").contains("group:PLAN_FREE");
    assertThat(html).contains("data-settings-search").contains("data-key=\"FREE_ADS_REMOVED\"");
    assertThat(html).contains("2026-10-18 09:05").contains("· admin").contains("실증");
    assertThat(html).contains("기본값과 다름");
  }

  @Test
  @DisplayName("이력 없는 키는 '기본 설정 (변경 이력 없음)', 이력 없이 바뀐 값은 그렇게 표시한다")
  void settingsPage_noHistoryTexts() {
    String html = render("admin/settings", settingsModel(List.of(
      row("A_KEY", "기본 그대로", false, false, null, null),
      row("B_KEY", "DB 에서 바뀜", true, false, null, null))));

    assertThat(html).contains("기본 설정 (변경 이력 없음)").contains("변경 이력 없음 (이력 없이 바뀐 값)");
  }

  @Test
  @DisplayName("비밀값 행은 설정됨만 보이고 값 자리가 비어 있다")
  void settingsPage_secretRow_hasNoValue() {
    String html = render("admin/settings", settingsModel(List.of(
      row("OPENAI_API_KEY", "OpenAI 키", false, true, LocalDateTime.of(2026, 10, 1, 0, 0), null))));

    assertThat(html).contains("설정됨").contains("data-secret=\"true\"").doesNotContain("data-current=");
  }

  @Test
  @DisplayName("변경 이력 화면: 키·변경자·기간 필터, 정렬 헤더, 페이저가 조건을 유지한다")
  void historyPage_rendersFiltersSortAndPager() {
    AdminListQuery query = AdminListQuery.of("100%", Map.of("key", "FREE_ADS_REMOVED", "from", "2026-10-01"),
      null, "2", AdminSettingsHistoryService.DEFINITION);
    Map<String, Object> model = new HashMap<>();
    model.put("definition", AdminSettingsHistoryService.DEFINITION);
    model.put("query", query);
    model.put("page", new PageImpl<>(List.of(), PageRequest.of(1, 20), 100));
    model.put("rows", List.of(new AdminListRow(null, Map.of("createdAt", "2026-10-18 09:05",
      "configKey", "FREE_ADS_REMOVED", "change", "false → true", "changedBy", "admin", "reason", "-"))));
    model.put("baseUrl", "/admin/settings/history" + query.toQueryString(query.sort(), 1));
    model.put("configKeyNames", List.of("FREE_ADS_REMOVED"));

    String html = render("admin/settings-history", model);

    assertThat(html).contains("설정 변경 이력").contains("name=\"changedBy\"").contains("type=\"date\"")
      .contains("value=\"FREE_ADS_REMOVED\"").contains("value=\"2026-10-01\"");
    assertThat(html).contains("시각 ▼").contains("false → true");
    assertThat(html).contains("data-admin-pager").contains("2 / 5").contains("page=1").contains("page=3")
      .contains("key=FREE_ADS_REMOVED");
  }
}
