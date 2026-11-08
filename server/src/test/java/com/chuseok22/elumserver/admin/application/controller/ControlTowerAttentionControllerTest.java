package com.chuseok22.elumserver.admin.application.controller;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.matchesPattern;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardAttention;
import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardSummary;
import com.chuseok22.elumserver.admin.application.service.AdminDashboardService;
import com.chuseok22.elumserver.admin.application.service.ControlTowerAttentionService;
import com.chuseok22.elumserver.admin.application.service.ControlTowerTokenVerifier;
import com.chuseok22.elumserver.ai.application.dto.response.AiHealthSnapshot;
import com.chuseok22.elumserver.ai.application.dto.response.AiProviderStatus;
import com.chuseok22.elumserver.ai.core.AiProviderHealth;
import com.chuseok22.elumserver.common.infrastructure.logging.InstanceInfo;
import com.chuseok22.elumserver.common.infrastructure.properties.ControlTowerAttentionProperties;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.talk.application.service.TalkAdminService;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/**
 * 관제소 수집 GET /control/attention 계약 (attention v1, #1229): 404 꺼짐, 401 토큰, 200 본문 모양·수준, 503 집계 실패
 * 서비스·토큰 검사는 실제 객체, 집계 원천(대시보드·이야기·설정)만 가짜
 */
class ControlTowerAttentionControllerTest {

  private static final String PATH = "/control/attention";
  private static final String CURRENT_TOKEN = "current-token-value";
  private static final String PREVIOUS_TOKEN = "previous-token-value";
  private static final String ADMIN_BASE_URL = "https://api.elum.example";
  // 관제소 규격 generated_at: UTC ISO 8601, Z 로 끝남
  private static final String UTC_ISO_PATTERN = "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(\\.\\d{1,9})?Z$";

  private AdminDashboardService adminDashboardService;
  private TalkAdminService talkAdminService;
  private SystemConfigService systemConfigService;
  private MockEnvironment environment;

  @BeforeEach
  void setUp() {
    adminDashboardService = mock(AdminDashboardService.class);
    talkAdminService = mock(TalkAdminService.class);
    systemConfigService = mock(SystemConfigService.class);
    environment = new MockEnvironment();
    when(systemConfigService.getBoolean(ConfigKey.CONTROL_TOWER_ATTENTION_ENABLED)).thenReturn(true);
    givenAttention(new AdminDashboardAttention(0, 0, 0, new AiHealthSnapshot(List.of(), List.of()), -1, 0));
  }

  private void givenAttention(AdminDashboardAttention attention) {
    AdminDashboardSummary summary = mock(AdminDashboardSummary.class);
    when(summary.attention()).thenReturn(attention);
    when(adminDashboardService.summary()).thenReturn(summary);
  }

  private MockMvc mockMvcWith(String token, String previousToken) {
    ControlTowerAttentionProperties properties =
      new ControlTowerAttentionProperties(token, previousToken, ADMIN_BASE_URL + "/");
    ControlTowerAttentionService service = new ControlTowerAttentionService(adminDashboardService, talkAdminService,
      systemConfigService, properties, new ControlTowerTokenVerifier(properties), environment,
      new InstanceInfo("blue", "8080", "2.87.2", Instant.EPOCH));
    return MockMvcBuilders.standaloneSetup(new ControlTowerAttentionController(service)).build();
  }

  private ResultActions requestWithToken(MockMvc mockMvc, String presentedToken) throws Exception {
    return mockMvc.perform(get(PATH).header("X-Control-Token", presentedToken));
  }

  @Test
  @DisplayName("토큰 헤더가 없으면 401")
  void withoutTokenHeader_is401() throws Exception {
    mockMvcWith(CURRENT_TOKEN, "").perform(get(PATH)).andExpect(status().isUnauthorized());
  }

  @Test
  @DisplayName("틀린 토큰이면 401")
  void wrongToken_is401() throws Exception {
    requestWithToken(mockMvcWith(CURRENT_TOKEN, PREVIOUS_TOKEN), "wrong-token").andExpect(status().isUnauthorized());
  }

  @Test
  @DisplayName("서버에 토큰이 하나도 없으면 빈 헤더·아무 값 모두 401")
  void noConfiguredToken_alwaysIs401() throws Exception {
    MockMvc mockMvc = mockMvcWith("  ", null);

    requestWithToken(mockMvc, "anything").andExpect(status().isUnauthorized());
    requestWithToken(mockMvc, "").andExpect(status().isUnauthorized());
  }

  @Test
  @DisplayName("교체 기간: 현재 토큰과 이전 토큰 모두 200")
  void currentAndPreviousToken_areAccepted() throws Exception {
    MockMvc mockMvc = mockMvcWith(CURRENT_TOKEN, PREVIOUS_TOKEN);

    requestWithToken(mockMvc, CURRENT_TOKEN).andExpect(status().isOk());
    requestWithToken(mockMvc, PREVIOUS_TOKEN).andExpect(status().isOk());
  }

  @Test
  @DisplayName("연동이 꺼져 있으면 맞는 토큰이어도 404")
  void disabled_is404() throws Exception {
    when(systemConfigService.getBoolean(ConfigKey.CONTROL_TOWER_ATTENTION_ENABLED)).thenReturn(false);

    requestWithToken(mockMvcWith(CURRENT_TOKEN, ""), CURRENT_TOKEN).andExpect(status().isNotFound());
  }

  @Test
  @DisplayName("0건이어도 항목 6개가 모두 ok 로 나가고 상한 꺼짐이면 budget limit 이 없다")
  void zeroCounts_allSixItemsOk() throws Exception {
    requestWithToken(mockMvcWith(CURRENT_TOKEN, ""), CURRENT_TOKEN)
      .andExpect(status().isOk())
      .andExpect(header().string("Cache-Control", "no-store"))
      .andExpect(jsonPath("$.schema").value("attention"))
      .andExpect(jsonPath("$.version").value("1.0"))
      .andExpect(jsonPath("$.source.app").value("elum-server"))
      .andExpect(jsonPath("$.source.app_version").value("2.87.2"))
      .andExpect(jsonPath("$.source.environment").value("development"))
      .andExpect(jsonPath("$.source.admin_base_url").value(ADMIN_BASE_URL))
      .andExpect(jsonPath("$.generated_at").value(matchesPattern(UTC_ISO_PATTERN)))
      .andExpect(jsonPath("$.items", hasSize(6)))
      .andExpect(jsonPath("$.items[*].key").value(contains(
        "feedback.new", "review.pending", "job.stuck", "ai.alert", "report.unresolved", "budget.daily")))
      .andExpect(jsonPath("$.items[*].level").value(contains("ok", "ok", "ok", "ok", "ok", "ok")))
      .andExpect(jsonPath("$.items[0].kind").value("count"))
      .andExpect(jsonPath("$.items[0].count").value(0))
      .andExpect(jsonPath("$.items[5].kind").value("gauge"))
      .andExpect(jsonPath("$.items[5].value").value(0.0))
      .andExpect(jsonPath("$.items[5].unit").value("USD"))
      .andExpect(jsonPath("$.items[5].limit").doesNotExist())
      .andExpect(jsonPath("$.items[5].count").doesNotExist());
  }

  @Test
  @DisplayName("건수가 있으면 의견·검토 대기 info, 멈춘 예약·AI 이상·신고 warning, 상한 100% critical, 관리자 주소는 https 절대 주소")
  void nonZeroCounts_levelsAndAdminUrls() throws Exception {
    AiProviderStatus alertStatus = new AiProviderStatus("Gemini 글", AiProviderHealth.KEY_INVALID, 3, 0, 0,
      null, null, null, null);
    givenAttention(new AdminDashboardAttention(2, 1, 4, new AiHealthSnapshot(List.of(alertStatus), List.of()), 10, 12.5));
    when(talkAdminService.countUnresolvedReports()).thenReturn(3L);
    environment.setActiveProfiles("prod");

    requestWithToken(mockMvcWith(CURRENT_TOKEN, ""), CURRENT_TOKEN)
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.source.environment").value("production"))
      .andExpect(jsonPath("$.items[*].count").value(contains(2, 1, 4, 1, 3)))
      .andExpect(jsonPath("$.items[*].level").value(contains("info", "info", "warning", "warning", "warning", "critical")))
      .andExpect(jsonPath("$.items[0].admin_url").value(ADMIN_BASE_URL + "/admin/feedback?status=NEW"))
      .andExpect(jsonPath("$.items[4].admin_url").value(ADMIN_BASE_URL + "/admin/talk/reports"))
      .andExpect(jsonPath("$.items[5].value").value(12.5))
      .andExpect(jsonPath("$.items[5].limit").value(10.0));
  }

  @Test
  @DisplayName("집계가 실패하면 503 (관제소는 마지막 값 유지)")
  void snapshotFailure_is503() throws Exception {
    when(talkAdminService.countUnresolvedReports()).thenThrow(new IllegalStateException("talk table missing"));

    requestWithToken(mockMvcWith(CURRENT_TOKEN, ""), CURRENT_TOKEN)
      .andExpect(status().isServiceUnavailable())
      .andExpect(content().string(""));
  }
}
