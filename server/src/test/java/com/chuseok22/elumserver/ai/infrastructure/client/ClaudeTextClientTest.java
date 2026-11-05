package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalogs;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.ClaudeApiKeyService;
import com.chuseok22.elumserver.ai.application.service.ClaudeKeyHealthTracker;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.ClaudeApiKey;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse.UsageMetadata;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.ExpectedCount;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;

/**
 * Claude 텍스트 (#1083): 키 넘김 순서·요청 모양·응답 읽기. 실제 Anthropic 은 부르지 않는다
 * 깨지면: 1순위 키가 한도·크레딧 소진일 때 일과 만들기가 실패하거나, 고칠 수 없는 실패에 키를 낭비함
 */
class ClaudeTextClientTest {

  private static final String URL = "https://api.anthropic.com/v1/messages";
  private static final String KEY_ONE = "sk-ant-key-one-0000000000000000";
  private static final String KEY_TWO = "sk-ant-key-two-0000000000000000";
  private static final String OK_BODY = """
    {"content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\\"pictogramId\\":\\"toothbrush\\"}"}],
     "stop_reason":"end_turn",
     "usage":{"input_tokens":100,"output_tokens":20,"cache_read_input_tokens":5,"cache_creation_input_tokens":0}}
    """;

  private MockRestServiceServer server;
  private AiCallLogService aiCallLogService;
  private ClaudeApiKeyService keyService;
  private ClaudeKeyHealthTracker healthTracker;
  private ClaudeTextClient client;

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder().baseUrl("https://api.anthropic.com");
    server = MockRestServiceServer.bindTo(builder).build();
    AiRestClientFactory factory = mock(AiRestClientFactory.class);
    when(factory.create(any())).thenReturn(builder.build());
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.CLAUDE_TEXT_MODEL)).thenReturn("claude-haiku-5-5");
    when(config.getString(ConfigKey.CLAUDE_TEXT_EFFORT)).thenReturn("UNSET");
    aiCallLogService = mock(AiCallLogService.class);
    keyService = mock(ClaudeApiKeyService.class);
    when(keyService.enabledKeys()).thenReturn(List.of(
      new ClaudeApiKey("id-one", "회사 키", KEY_ONE, true),
      new ClaudeApiKey("id-two", "개인 키", KEY_TWO, true)));
    healthTracker = new ClaudeKeyHealthTracker(Clock.systemDefaultZone());
    GeminiTextClient gemini = new GeminiTextClient(mock(RestClient.class),
      new GeminiProperties("k", null, "m", "i", 1000), mock(PromptTemplateService.class), config, aiCallLogService,
      PictogramCatalogs.mulberryOnly(new PictogramCatalog(List.of("toothbrush"), "toothbrush")));
    client = new ClaudeTextClient(gemini, mock(PromptTemplateService.class), config, aiCallLogService, keyService,
      healthTracker, factory);
  }

  private void respond(String apiKey, HttpStatus status, String body) {
    server.expect(ExpectedCount.once(), requestTo(URL))
      .andExpect(method(HttpMethod.POST))
      .andExpect(header("x-api-key", apiKey))
      .andRespond(withStatus(status).contentType(MediaType.APPLICATION_JSON).body(body));
  }

  @Test
  @DisplayName("1순위 키가 429(한도)면 2순위 키로 같은 요청을 보내 결과를 돌려주고, 기록에는 키 별명만 남는다")
  void rateLimitedFirstKey_movesToSecondKey() {
    respond(KEY_ONE, HttpStatus.TOO_MANY_REQUESTS, "{\"type\":\"error\"}");
    respond(KEY_TWO, HttpStatus.OK, OK_BODY);

    String json = client.pickPictogramJson("이를 닦아요", "칫솔로 이를 닦아요");

    assertThat(json).isEqualTo("{\"pictogramId\":\"toothbrush\"}");
    server.verify();
    verify(aiCallLogService).recordFailure(eq(AiCallType.CLAUDE_TEXT_PICTOGRAM), eq("claude-haiku-5-5"), anyLong(),
      anyString(), eq("회사 키"));
    verify(aiCallLogService).recordSuccess(eq(AiCallType.CLAUDE_TEXT_PICTOGRAM), eq("claude-haiku-5-5"), anyLong(),
      any(), eq("개인 키"));
    assertThat(healthTracker.isCoolingDown("id-one")).isTrue();
    assertThat(healthTracker.lastServedKeyId()).contains("id-two");
  }

  @Test
  @DisplayName("401(키 오류)·크레딧 부족(400 credit balance)도 다음 키로 넘긴다")
  void invalidKeyOrCreditExhausted_movesToNextKey() {
    respond(KEY_ONE, HttpStatus.UNAUTHORIZED, "");
    respond(KEY_TWO, HttpStatus.BAD_REQUEST,
      "{\"type\":\"error\",\"error\":{\"type\":\"invalid_request_error\",\"message\":\"Your credit balance is too low\"}}");

    assertThatThrownBy(() -> client.pickPictogramJson("t", "d")).isInstanceOf(HttpClientErrorException.class);
    server.verify();
    assertThat(healthTracker.isCoolingDown("id-one")).isTrue();
    assertThat(healthTracker.isCoolingDown("id-two")).isTrue();
  }

  @Test
  @DisplayName("요청 형식 400 은 다른 키로 고쳐지지 않아 2순위 키를 부르지 않고 바로 던진다 (제공자 사슬이 받음)")
  void badRequest_doesNotTryNextKey() {
    respond(KEY_ONE, HttpStatus.BAD_REQUEST,
      "{\"type\":\"error\",\"error\":{\"type\":\"invalid_request_error\",\"message\":\"bad schema\"}}");

    assertThatThrownBy(() -> client.pickPictogramJson("t", "d")).isInstanceOf(HttpClientErrorException.class);
    server.verify();
    assertThat(healthTracker.isCoolingDown("id-one")).isFalse();
  }

  @Test
  @DisplayName("쉬는 중인 1순위 키는 뒤로 미뤄 2순위 키부터 쓴다")
  void coolingKey_triedLast() {
    healthTracker.onFailure("id-one", com.chuseok22.elumserver.ai.core.AiFailureKind.RATE_LIMIT);
    respond(KEY_TWO, HttpStatus.OK, OK_BODY);

    client.pickPictogramJson("t", "d");

    server.verify();
  }

  @Test
  @DisplayName("요청: 모델·최대 토큰·시스템 지시·JSON 스키마(output_config.format), temperature 는 싣지 않는다")
  void requestBody_shape() {
    server.expect(requestTo(URL))
      .andExpect(header("anthropic-version", ClaudeTextClient.ANTHROPIC_VERSION))
      .andExpect(jsonPath("$.model").value("claude-haiku-5-5"))
      .andExpect(jsonPath("$.max_tokens").value(ClaudeTextClient.MAX_OUTPUT_TOKENS))
      .andExpect(jsonPath("$.system").isNotEmpty())
      .andExpect(jsonPath("$.messages[0].role").value("user"))
      .andExpect(jsonPath("$.output_config.format.type").value("json_schema"))
      .andExpect(jsonPath("$.output_config.format.schema.additionalProperties").value(false))
      .andExpect(jsonPath("$.output_config.effort").doesNotExist())
      .andExpect(jsonPath("$.temperature").doesNotExist())
      .andRespond(withSuccess(OK_BODY, MediaType.APPLICATION_JSON));

    client.pickPictogramJson("t", "d");

    server.verify();
  }

  @Test
  @DisplayName("effort 를 정하면 output_config.effort 로 싣는다")
  void effort_includedWhenSet() {
    Map<String, Object> body = ClaudeTextClient.buildRequestBody(
      "claude-haiku-5-5", "s", "u", Map.of("type", "object", "properties", Map.of()), "low");

    assertThat(((Map<?, ?>) body.get("output_config")).get("effort")).isEqualTo("low");
  }

  @Test
  @DisplayName("토큰 기록: 입력은 일반+캐시 토큰 합, 출력은 생각 포함 출력 토큰")
  void usage_mappedForCost() {
    respond(KEY_ONE, HttpStatus.OK, OK_BODY);

    client.pickPictogramJson("t", "d");

    ArgumentCaptor<UsageMetadata> usage = ArgumentCaptor.forClass(UsageMetadata.class);
    verify(aiCallLogService).recordSuccess(any(), any(), anyLong(), usage.capture(), eq("회사 키"));
    assertThat(usage.getValue().promptTokenCount()).isEqualTo(105);
    assertThat(usage.getValue().billableOutputTokens()).isEqualTo(20);
  }

  @Test
  @DisplayName("안전 거절(stop_reason=refusal)은 형식이 맞지 않을 수 있어 실패로 던진다 — 다음 키는 부르지 않는다")
  void refusal_throws() {
    respond(KEY_ONE, HttpStatus.OK,
      "{\"content\":[{\"type\":\"text\",\"text\":\"no\"}],\"stop_reason\":\"refusal\",\"usage\":{}}");

    assertThatThrownBy(() -> client.pickPictogramJson("t", "d"))
      .isInstanceOf(IllegalStateException.class).hasMessageContaining("refusal");
    server.verify();
  }

  @Test
  @DisplayName("켜진 키가 없으면 쓸 수 없는 제공자 — 관리자 화면이 전환을 막는다")
  void noEnabledKey_notAvailable() {
    when(keyService.hasEnabledKey()).thenReturn(false);

    assertThat(client.available()).isFalse();
  }
}
