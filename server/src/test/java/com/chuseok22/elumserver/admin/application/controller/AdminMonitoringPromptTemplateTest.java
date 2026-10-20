package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminAiMonthSummary;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMonitoringList;
import com.chuseok22.elumserver.ai.application.dto.response.AiFailureCount;
import com.chuseok22.elumserver.ai.application.dto.response.AiHealthSnapshot;
import com.chuseok22.elumserver.ai.application.dto.response.AiProviderStatus;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.AiFailureKind;
import com.chuseok22.elumserver.ai.core.AiProviderHealth;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplateHistory;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.AiCallStats;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 모니터링 필터 폼, 프롬프트 수정자, 약관·프롬프트 시각 표기가 실제로 그려지는지 (#758).
 * 식 하나가 틀리면 그 화면은 500 인데 컴파일로는 안 잡힌다. 템플릿 엔진만으로 그려 본다.
 */
class AdminMonitoringPromptTemplateTest {

  private static final LocalDateTime SAVED_AT = LocalDateTime.of(2026, 10, 19, 9, 5, 33);

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  private AiCallStats stats() {
    AiCallStats stats = mock(AiCallStats.class);
    when(stats.getTotalCount()).thenReturn(0L);
    return stats;
  }

  private String renderMonitoring(Map<String, String> filters, List<AiCallLog> calls, int totalElements) {
    AdminListQuery query = AdminMonitoringList.withCorrectedPeriod(
      AdminListQuery.of(null, filters, null, null, AdminMonitoringList.DEFINITION), LocalDate.of(2026, 10, 19));
    Map<String, Object> model = new HashMap<>();
    model.put("todayStats", stats());
    model.put("totalStats", stats());
    model.put("calls", new PageImpl<>(calls, PageRequest.of(0, 1), totalElements));
    model.put("callTypes", AiCallType.values());
    model.put("definition", AdminMonitoringList.DEFINITION);
    model.put("query", query);
    model.put("pagerBaseUrl", "/admin/monitoring" + query.toQueryString(query.sort(), 1));
    model.put("monthSummary", new AdminAiMonthSummary(12, 8.3, 1.5, 2100, 40L, List.of(
      new AdminAiMonthSummary.ProviderCost("OpenAI 그림", 1.2), new AdminAiMonthSummary.ProviderCost("Gemini 글", 0.3))));
    model.put("aiHealth", new AiHealthSnapshot(
      List.of(new AiProviderStatus("OpenAI 글", AiProviderHealth.CREDIT_EXHAUSTED, 2, 0, 900, null, SAVED_AT,
        AiFailureKind.CREDIT, "429 Too Many Requests: You have no credits remaining")),
      List.of(new AiFailureCount(AiFailureKind.CREDIT, "OpenAI 글", 4, SAVED_AT))));
    return renderer.render("admin/monitoring", model);
  }

  @Test
  @DisplayName("AI 상태·이번 달 요약·제공자 비용 비율·실패 원인·추이 카드가 그려진다")
  void rendersHealthSummaryAndTrendCard() {
    String html = renderMonitoring(Map.of(), List.of(), 0);

    assertThat(html).contains("data-ai-health", "크레딧 소진 의심", "badge-error", "24시간 안에 없음",
      "data-month-summary", "약 2,100원", "약 40원", "8.3%",
      "data-provider-costs", "(80%)", "width:80%",
      "크레딧·결제", "data-trend-chart", "/admin/stats/api/ai-usage", "/admin/vendor/chart.umd.min.js");
  }

  private AiCallLog call(String memberId) {
    AiCallLog log = new AiCallLog();
    log.setMemberId(memberId);
    log.setCallType(AiCallType.GEMINI_IMAGE);
    log.setSuccess(true);
    ReflectionTestUtils.setField(log, "createdAt", SAVED_AT);
    return log;
  }

  @Test
  @DisplayName("모니터링: 기간 기본값(최근 7일)과 선택한 필터가 폼에 채워지고, 페이저가 필터를 유지한다")
  void monitoringFormKeepsFilters() {
    Map<String, String> filters = new HashMap<>();
    filters.put("callType", "GEMINI_IMAGE");
    filters.put("memberId", "member-1");

    String html = renderMonitoring(filters, List.of(call("member-1")), 120);

    assertThat(html).contains("name=\"from\"").contains("value=\"2026-10-13\"").contains("value=\"2026-10-19\"");
    assertThat(html).contains("value=\"member-1\"");
    assertThat(html).containsPattern("<option[^>]*value=\"GEMINI_IMAGE\"[^>]*selected");
    assertThat(html).contains("memberId=member-1").contains("callType=GEMINI_IMAGE").contains("from=2026-10-13");
    assertThat(html).contains("data-admin-pager");
  }

  @Test
  @DisplayName("모니터링: 0건이면 빈 상태 줄을 그린다")
  void monitoringEmptyState() {
    String html = renderMonitoring(new HashMap<>(), List.of(), 0);

    assertThat(html).contains("조건에 맞는 AI 호출이 없어요");
  }

  private PromptTemplate prompt() {
    PromptTemplate prompt = new PromptTemplate();
    prompt.setPromptKey(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    prompt.setLocale("ko");
    prompt.setContent("지시문");
    ReflectionTestUtils.setField(prompt, "updatedAt", SAVED_AT);
    return prompt;
  }

  @Test
  @DisplayName("프롬프트 목록: 마지막 수정 시각은 공통 포맷, 수정자는 기록된 이름이고 기록이 없으면 '-'")
  void promptListShowsChanger() {
    Map<String, Object> withChanger = Map.of("prompts", List.of(prompt()),
      "latestChangerByKey", Map.of(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "kimchi"));
    Map<String, Object> legacy = Map.of("prompts", List.of(prompt()), "latestChangerByKey", Map.of());

    String html = renderer.render("admin/prompts", withChanger);
    String legacyHtml = renderer.render("admin/prompts", legacy);

    assertThat(html).contains("2026-10-19 09:05").contains("· kimchi").doesNotContain("09:05:33");
    assertThat(legacyHtml).contains("2026-10-19 09:05").contains("· -");
  }

  @Test
  @DisplayName("프롬프트 이력: 교체 시각은 공통 포맷, 수정자는 이름 또는 '-' (기존 행)")
  void promptHistoryShowsChanger() {
    PromptTemplateHistory recorded = new PromptTemplateHistory();
    recorded.setPromptKey(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    recorded.setContent("이전");
    recorded.setChangedBy("kimchi");
    ReflectionTestUtils.setField(recorded, "createdAt", SAVED_AT);
    PromptTemplateHistory legacy = new PromptTemplateHistory();
    legacy.setPromptKey(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    legacy.setContent("더 이전");
    ReflectionTestUtils.setField(legacy, "createdAt", SAVED_AT.minusDays(1));

    String html = renderer.render("admin/prompt-history", Map.of(
      "prompt", prompt(), "histories", List.of(recorded, legacy), "selectedLocale", "ko"));

    assertThat(html).contains("2026-10-19 09:05").contains("2026-10-18 09:05");
    assertThat(html).contains("수정자 <span>kimchi</span>").contains("수정자 <span>-</span>");
  }

  @Test
  @DisplayName("약관 목록·이력: 시각을 공통 포맷으로 그리고, 값이 없으면 '-'")
  void consentDatesUseAdminFormat() {
    ConsentDocument document = new ConsentDocument();
    document.setConsentKey(ConsentKey.values()[0]);
    document.setVersion("2026-10-19");
    document.setLabel("이용약관");
    document.setSummary("요약");
    document.setBody("본문");
    document.setPublishedAt(SAVED_AT);
    ConsentDocumentHistory history = new ConsentDocumentHistory();
    history.setConsentKey(ConsentKey.values()[0]);
    history.setVersion("2026-10-18");
    history.setLabel("이용약관");
    history.setSummary("요약");
    history.setBody("본문");
    history.setChangedBy("kimchi");
    history.setReason("문구 수정");
    ReflectionTestUtils.setField(history, "createdAt", SAVED_AT);

    String list = renderer.render("admin/consents", Map.of("documents", List.of(document), "bundleVersion", "v1"));
    String historyHtml = renderer.render("admin/consent-history",
      Map.of("document", document, "histories", List.of(history)));

    assertThat(list).contains("2026-10-19 09:05");
    assertThat(list).doesNotContain("09:05:33");
    assertThat(historyHtml).contains("2026-10-19 09:05");
  }
}
