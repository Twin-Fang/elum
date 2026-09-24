package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withBadRequest;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.ExpectedCount;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

/**
 * Gemini 생각(thinking) 토큰 (#375).
 *
 * <p>실제 Gemini 를 부르지 않는다. 가짜 서버로 "무엇을 보냈나 · 몇 번 보냈나 · 무엇을 기록했나" 만 본다.
 */
class GeminiTextClientThinkingTest {

  private static final String OK_BODY = """
    {"candidates":[{"content":{"parts":[{"text":"{\\"title\\":\\"t\\",\\"steps\\":[]}"}]}}],
     "usageMetadata":{"promptTokenCount":1310,"candidatesTokenCount":233,
                      "totalTokenCount":2043,"thoughtsTokenCount":500}}
    """;

  private MockRestServiceServer server;
  private SystemConfigService systemConfigService;
  private AiCallLogService aiCallLogService;
  private GeminiTextClient client;

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder().baseUrl("https://gemini.test");
    server = MockRestServiceServer.bindTo(builder).build();
    systemConfigService = mock(SystemConfigService.class);
    aiCallLogService = mock(AiCallLogService.class);
    PromptTemplateService promptTemplateService = mock(PromptTemplateService.class);
    when(promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX)).thenReturn("지시문");
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).thenReturn("gemini-flash-latest");
    when(systemConfigService.getDouble(ConfigKey.GEMINI_TEXT_TEMPERATURE)).thenReturn(0.0);
    client = new GeminiTextClient(
      builder.build(), new GeminiProperties("key", null, "text-model", "image-model", 1000),
      promptTemplateService, systemConfigService, aiCallLogService
    );
  }

  private void budget(String value) {
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_THINKING_BUDGET)).thenReturn(value);
  }

  @Test
  @DisplayName("기본값(UNSET)이면 thinkingConfig 를 보내지 않는다 — 배포만으로 동작이 바뀌지 않는다")
  void unset_sendsNoThinkingConfig() {
    budget("UNSET");

    Map<String, Object> config = client.generationConfig(Map.of("type", "object"));

    assertThat(config).doesNotContainKey("thinkingConfig");
    assertThat(config).containsKeys("responseMimeType", "responseSchema", "temperature");
  }

  @Test
  @DisplayName("0 으로 두면 thinkingConfig.thinkingBudget=0 을 보낸다 — 관리자가 생각을 끈다")
  void zero_sendsThinkingBudgetZero() {
    budget("0");

    Map<String, Object> config = client.generationConfig(Map.of("type", "object"));

    assertThat(config.get("thinkingConfig")).isEqualTo(Map.of("thinkingBudget", 0));
  }

  @Test
  @DisplayName("값이 망가져 있으면 보내지 않는다 — 설정 하나 때문에 일과 만들기가 400 으로 죽지 않게")
  void corrupted_sendsNoThinkingConfig() {
    budget("abc");

    assertThat(client.generationConfig(Map.of("type", "object"))).doesNotContainKey("thinkingConfig");
  }

  @Test
  @DisplayName("실제 요청 본문에 thinkingBudget 이 실리고, 응답의 생각 토큰이 기록까지 간다")
  void request_carriesBudget_andLogKeepsThoughts() {
    budget("0");
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.generationConfig.thinkingConfig.thinkingBudget").value(0))
      .andRespond(withSuccess(OK_BODY, MediaType.APPLICATION_JSON));

    client.generateRoutineJson("비 오는 날 학교 가기", null, Set.of(), List.of());

    server.verify();
    ArgumentCaptor<GeminiGenerateContentResponse.UsageMetadata> usage =
      ArgumentCaptor.forClass(GeminiGenerateContentResponse.UsageMetadata.class);
    verify(aiCallLogService).recordSuccess(
      eq(AiCallType.GEMINI_TEXT_CREATE), eq("gemini-flash-latest"), anyLong(), usage.capture());
    assertThat(usage.getValue().thoughtsTokenCount()).isEqualTo(500);
  }

  @Test
  @DisplayName("모델이 thinkingBudget 을 거절해 400 을 주면 다시 부르지 않고 실패로 남긴다 — T3")
  void badRequest_isNotRetried() {
    budget("0");
    // 한 번만 기대한다. 두 번째 요청이 나가면 가짜 서버가 AssertionError 를 던진다.
    server.expect(ExpectedCount.once(), method(HttpMethod.POST))
      .andRespond(withBadRequest().body("{\"error\":{\"message\":\"thinking budget not supported\"}}")
        .contentType(MediaType.APPLICATION_JSON));

    assertThatThrownBy(() -> client.generateRoutineJson("병원 가기", null, Set.of(), List.of()))
      .isInstanceOf(HttpClientErrorException.BadRequest.class);

    server.verify();
    verify(aiCallLogService, times(1)).recordFailure(
      eq(AiCallType.GEMINI_TEXT_CREATE), eq("gemini-flash-latest"), anyLong(), any());
    verify(aiCallLogService, never()).recordSuccess(any(), any(), anyLong(), any());
  }
}
