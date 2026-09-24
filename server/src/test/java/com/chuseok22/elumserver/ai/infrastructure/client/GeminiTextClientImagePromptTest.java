package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
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
import org.hamcrest.Matchers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/**
 * FLUX 용 영어 장면 한 줄 (#373).
 *
 * <p>일과 만들기와 <b>같은 호출</b>에서 카드마다 받는다 — 호출이 늘지 않는다. 다만 FLUX 를 고르지
 * 않았을 때는 스키마에 넣지 않는다. 카드 6장이면 출력이 백여 토큰 늘어 글 값이 30% 가까이 오르는데,
 * 쓰지도 않을 문장에 낼 이유가 없다 (#375 가 토큰을 줄이는 이슈다).
 */
class GeminiTextClientImagePromptTest {

  private MockRestServiceServer server;
  private AiCallLogService aiCallLogService;
  private GeminiTextClient client;

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder().baseUrl("https://gemini.test");
    server = MockRestServiceServer.bindTo(builder).build();
    SystemConfigService systemConfigService = mock(SystemConfigService.class);
    aiCallLogService = mock(AiCallLogService.class);
    PromptTemplateService promptTemplateService = mock(PromptTemplateService.class);
    when(promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX)).thenReturn("지시문");
    when(promptTemplateService.getContent(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE)).thenReturn("Rewrite.");
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).thenReturn("gemini-flash-latest");
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_THINKING_BUDGET)).thenReturn("UNSET");
    when(systemConfigService.getDouble(ConfigKey.GEMINI_TEXT_TEMPERATURE)).thenReturn(0.0);
    client = new GeminiTextClient(
      builder.build(), new GeminiProperties("key", null, "text-model", "image-model", 1000),
      promptTemplateService, systemConfigService, aiCallLogService
    );
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> stepProperties(Map<String, Object> schema) {
    Map<String, Object> steps = (Map<String, Object>) ((Map<String, Object>) schema.get("properties")).get("steps");
    Map<String, Object> items = (Map<String, Object>) steps.get("items");
    return items;
  }

  @Test
  @DisplayName("FLUX 면 카드마다 imagePromptEn 을 필수로 받는다 — 설명에 'The character' 주어와 물건 상태를 적게 한다")
  void schemaWithImagePrompt() {
    Map<String, Object> items = stepProperties(client.responseSchema(true));

    @SuppressWarnings("unchecked")
    Map<String, Object> field = (Map<String, Object>) ((Map<String, Object>) items.get("properties")).get("imagePromptEn");
    assertThat(field).isNotNull();
    assertThat((String) field.get("description")).contains("The character").contains("English");
    assertThat((List<String>) items.get("required")).contains("imagePromptEn");
  }

  @Test
  @DisplayName("FLUX 가 아니면 스키마에 넣지 않는다 — 지금과 같은 출력 토큰")
  void schemaWithoutImagePrompt() {
    Map<String, Object> items = stepProperties(client.responseSchema(false));

    @SuppressWarnings("unchecked")
    Map<String, Object> properties = (Map<String, Object>) items.get("properties");
    assertThat(properties).doesNotContainKey("imagePromptEn");
    assertThat(client.responseSchema(false)).isEqualTo(client.responseSchema());
  }

  @Test
  @DisplayName("일과 만들기 요청이 imagePromptEn 스키마를 실어 보낸다 (같은 호출)")
  void createCall_sendsImagePromptSchema() {
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.generationConfig.responseSchema.properties.steps.items.properties.imagePromptEn")
        .exists())
      .andRespond(withSuccess(
        "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"{}\"}]}}]}", MediaType.APPLICATION_JSON));

    client.generateRoutineJson("비 오는 날 학교 가기", null, Set.of(), List.of(), true);

    server.verify();
  }

  @Test
  @DisplayName("번역은 짧은 프롬프트로 한 번 — 결과 한 줄을 돌려주고 호출 유형을 따로 남긴다")
  void translate_returnsLine_andLogsOwnType() {
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.systemInstruction.parts[0].text").value("Rewrite."))
      .andExpect(jsonPath("$.contents[0].parts[0].text", Matchers.containsString("우산을 챙겨요")))
      .andRespond(withSuccess(
        "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":"
          + "\"{\\\"imagePromptEn\\\":\\\" The character picks up a red umbrella.\\\\n\\\"}\"}]}}]}",
        MediaType.APPLICATION_JSON));

    String line = client.translateImagePrompt("우산을 챙겨요");

    assertThat(line).isEqualTo("The character picks up a red umbrella.");
    verify(aiCallLogService).recordSuccess(
      eq(AiCallType.GEMINI_TEXT_IMAGE_PROMPT), eq("gemini-flash-latest"), anyLong(), any());
  }

  @Test
  @DisplayName("번역 결과가 비면 실패로 던진다 — 부르는 쪽이 OpenAI 로 돌린다")
  void translate_blank_throws() {
    server.expect(method(HttpMethod.POST)).andRespond(withSuccess(
      "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"{\\\"imagePromptEn\\\":\\\"  \\\"}\"}]}}]}",
      MediaType.APPLICATION_JSON));

    assertThatThrownBy(() -> client.translateImagePrompt("우산을 챙겨요"))
      .isInstanceOf(IllegalStateException.class);
  }
}
