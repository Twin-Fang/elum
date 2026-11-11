package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionItem;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionLevel;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionResponse;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionSource;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerIntegrationPanel;
import com.chuseok22.elumserver.admin.application.dto.response.SettingRow;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsEditorView;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsSectionLink;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.Highlight;
import com.chuseok22.elumserver.admin.application.dto.response.SettingsOverview.PlanRow;
import com.chuseok22.elumserver.admin.application.format.AdminDateFormatter;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminListRow;
import com.chuseok22.elumserver.admin.application.service.AdminSettingsHistoryService;
import java.time.LocalDate;
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
 * 설정 화면(시스템·AI·요금제)·변경 이력 화면이 실제로 그려지는지: 요약, 다른 화면 바로가기, Free/Pro 비교, 표 행, 비밀값 가림
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
      isDifferent, isSecret, changedAt != null, changedAt, changedAt == null ? null : "admin", reason,
      "FREE_TEXT", "", null, "DB 저장값", null);
  }

  private Map<String, Object> settingsModel(List<SettingRow> rows) {
    SettingsOverview overview = new SettingsOverview(1,
      List.of(new Highlight("MAINTENANCE_MODE", "점검 모드", "꺼짐", false, false),
        new Highlight("FREE_ADS_REMOVED", "Free 광고 제거", "켜짐", true, true)),
      List.of(new PlanRow("광고 제거", "FREE_ADS_REMOVED", "켜짐", true, "PRO_ADS_REMOVED", "켜짐", false)));
    Map<String, Object> model = new HashMap<>();
    model.put("overview", overview);
    model.put("editor", editorOf(rows, 0L));
    model.put("sectionLinks", List.of(new SettingsSectionLink("AI 설정", "/admin/settings/ai", 32, 4),
      new SettingsSectionLink("광고 보상", "/admin/ad-rewards", 5, 0)));
    model.put("imageProviders", List.of());
    model.put("textProviders", List.of());
    return model;
  }

  private static SettingsEditorView editorOf(List<SettingRow> rows, long ruleWarningCount) {
    return new SettingsEditorView("/admin/settings", rows,
      new LinkedHashMap<>(Map.of("PLAN_FREE", "Free 플랜 한도", "PLAN_PRO", "Pro 플랜 한도")),
      ruleWarningCount, LocalDate.of(2026, 10, 18), null);
  }

  @Test
  @DisplayName("시스템 설정: 지금 적용 중·다른 화면 바로가기·표 열·칩·검색이 그려지고 기본값과 다른 값이 강조된다")
  void settingsPage_rendersSummaryLinksAndTable() {
    String html = render("admin/settings", settingsModel(List.of(
      row("FREE_ADS_REMOVED", "광고 제거", true, false, LocalDateTime.of(2026, 10, 18, 9, 5), "실증"))));

    assertThat(html).contains("data-settings-summary=\"highlights\"").contains("지금 적용 중");
    assertThat(html).contains("점검 모드").contains("badge-success");
    assertThat(html).as("Free/Pro 비교는 요금제·구독 화면으로 옮김").doesNotContain("data-plan-comparison");
    assertThat(html).contains("다른 화면에서 관리하는 설정").contains("href=\"/admin/settings/ai\"").contains("32개")
      .contains("바꾼 값 4");
    assertThat(html).contains("설정").contains("현재 값").contains("기본값").contains("마지막 변경");
    assertThat(html).contains("data-chip=\"different\"").contains("data-chip=\"today\"").contains("group:PLAN_FREE");
    assertThat(html).contains("data-settings-search").contains("data-key=\"FREE_ADS_REMOVED\"")
      .contains("data-refresh-url=\"/admin/settings\"");
    assertThat(html).contains("2026-10-18 09:05").contains("· admin").contains("실증");
    assertThat(html).contains("기본값과 다름");
  }

  @Test
  @DisplayName("시스템 설정: 관제소 연동 칸에 켜짐·토큰 설정 여부·마지막 수집·항목 미리보기가 그려지고 토큰 값은 없다")
  void settingsPage_rendersControlTowerPanel() {
    ControlTowerAttentionResponse preview = ControlTowerAttentionResponse.of(
      new ControlTowerAttentionSource("elum-server", "2.87.2", "production", "https://api.elum.example"),
      "2026-11-08T03:00:00Z",
      List.of(ControlTowerAttentionItem.count("feedback.new", "새 의견", 2, ControlTowerAttentionLevel.INFO, "/admin/feedback"),
        ControlTowerAttentionItem.gauge("budget.daily", "오늘 AI 비용", 1.5, null, "USD", ControlTowerAttentionLevel.OK,
          "/admin/settings/ai")));
    Map<String, Object> model = settingsModel(List.of());
    model.put("controlTowerPanel", new ControlTowerIntegrationPanel(true, true, true,
      LocalDateTime.of(2026, 11, 8, 12, 1), preview, null));

    String html = render("admin/settings", model);

    assertThat(html).contains("data-control-tower-panel").contains("관제소 연동");
    assertThat(html).contains("켜짐").contains("설정됨").contains("2026-11-08 12:01");
    assertThat(html).contains("data-item-key=\"feedback.new\"").contains("2건").contains("badge-info");
    assertThat(html).contains("data-item-key=\"budget.daily\"").contains("$1.50 (상한 꺼짐)");
    assertThat(html).contains("data-open-key=\"CONTROL_TOWER_ATTENTION_ENABLED\"");
  }

  @Test
  @DisplayName("시스템 설정: 관제소 칸 값이 없으면 칸만 빠지고 화면은 그려진다")
  void settingsPage_withoutControlTowerPanel_stillRenders() {
    String html = render("admin/settings", settingsModel(List.of()));

    assertThat(html).contains("지금 적용 중").doesNotContain("data-control-tower-panel");
  }

  @Test
  @DisplayName("지금 적용 중 항목은 그 설정이 있는 화면에서 패널을 여는 주소로 간다 — 옮긴 설정을 누르면 빈 패널이 되지 않는다")
  void settingsPage_highlightLinksToOwningPage() {
    String html = render("admin/settings", settingsModel(List.of()));

    assertThat(html).contains("href=\"/admin/settings#setting=MAINTENANCE_MODE\"")
      .contains("href=\"/admin/settings/plans#setting=FREE_ADS_REMOVED\"");
  }

  @Test
  @DisplayName("요금제·구독: Free/Pro 비교와 플랜 설정 표가 그려진다")
  void planSettingsPage_rendersComparisonAndTable() {
    String html = render("admin/settings-plans", settingsModel(List.of(
      row("FREE_ADS_REMOVED", "광고 제거", true, false, null, null))));

    assertThat(html).contains("Free / Pro 비교").contains("data-plan-comparison")
      .contains("data-settings-summary=\"plans\"");
    assertThat(html).as("기본값과 다른 Free 값은 노란 배지").contains("badge badge-warning");
    assertThat(html).contains("data-key=\"FREE_ADS_REMOVED\"").contains("data-settings-panel");
  }

  @Test
  @DisplayName("설정을 읽지 못하면 표 대신 오류 코드 안내만 보이고 수정 패널·스크립트는 붙지 않는다")
  void editor_loadFailure_showsErrorCodeOnly() {
    Map<String, Object> model = settingsModel(List.of());
    model.put("editor", SettingsEditorView.failed("/admin/settings", "설정을 불러오지 못했어요 (E-CFG-LOAD)"));

    String html = render("admin/settings", model);

    assertThat(html).contains("E-CFG-LOAD").doesNotContain("data-settings-table").doesNotContain("settings-panel.js");
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
  @DisplayName("저장값이 지금 규칙에 어긋나면 행에 경고 배지·이유와 걸러 보기 칩이 보인다 — 어긋난 값이 조용히 묻히지 않는다")
  void settingsPage_ruleWarning_showsBadgeAndChip() {
    SettingRow warnedRow = new SettingRow("MIN_APP_VERSION_IOS", "iOS 최소 버전", "설명", "APP_CONTROL", "앱 점검·버전",
      "STRING", List.of(), null, null, "v2.1", "v2.1", "", "(비어 있음)", true, false, false, null, null, null,
      "APP_VERSION", "숫자.숫자.숫자 (예: 2.69.1)", "버전은 2.69.1 로 적어요", "DB 저장값", null);
    Map<String, Object> model = settingsModel(List.of(warnedRow));
    model.put("editor", editorOf(List.of(warnedRow), 1L));

    String html = render("admin/settings", model);

    assertThat(html).contains("규칙에 어긋남").contains("버전은 2.69.1 로 적어요");
    assertThat(html).contains("data-chip=\"warning\"").contains("data-warning=\"true\"")
      .contains("data-format=\"APP_VERSION\"");
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

  @Test
  @DisplayName("AI 설정: 텍스트 제공자 순서·Claude 키 카드가 그려지고 키 값 대신 끝 4자리만 보인다 (#1083)")
  void aiSettingsPage_textChainAndClaudeKeys() {
    Map<String, Object> model = settingsModel(List.of());
    model.put("textProviders", List.of(
      new com.chuseok22.elumserver.admin.application.dto.response.AdminTextProviderView(
        "CLAUDE", "Claude", true, true, 0.10, 0.50, 1, false),
      new com.chuseok22.elumserver.admin.application.dto.response.AdminTextProviderView(
        "GEMINI", "Gemini", false, true, 0.30, 2.50, 2, true),
      new com.chuseok22.elumserver.admin.application.dto.response.AdminTextProviderView(
        "OPENAI", "OpenAI", false, false, 0.40, 1.60, 0, false)));
    model.put("claudeKeys", List.of(new com.chuseok22.elumserver.admin.application.dto.response.AdminClaudeKeyView(
      "k1", 1, "회사 키", "••••abcd", true, true, true, LocalDateTime.of(2026, 11, 5, 9, 0),
      LocalDateTime.of(2026, 11, 5, 9, 1), "한도 초과", LocalDateTime.of(2026, 11, 5, 9, 6), true, true)));

    String html = render("admin/settings-ai", model);

    assertThat(html).contains("AI 제공자 전환").contains("1번").contains("2번").contains("먼저 씀").contains("안 씀").contains("키를 먼저 넣으세요");
    assertThat(html).contains("data-claude-keys").contains("1순위").contains("회사 키").contains("••••abcd")
      .contains("지금 쓰는 키").contains("쉬는 중 ~09:06").contains("한도 초과").doesNotContain("sk-ant-api");
  }
}
