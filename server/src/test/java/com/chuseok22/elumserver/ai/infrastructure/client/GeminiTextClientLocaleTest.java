package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.jsonPath;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.ContentLanguageSpec;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.List;
import java.util.Set;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/**
 * 일과 언어가 AI 요청에 실리는 모양. 실제 Gemini 는 부르지 않는다 — 요청 본문을 가짜 서버가 받아 본다.
 * ko 는 지금과 글자까지 같아야 하고(ko 요청 불변), 그 밖의 언어는 스키마·픽토그램 지시가 그 언어를 말한다.
 */
class GeminiTextClientLocaleTest {

  private static final String OK = "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"{}\"}]}}]}";
  private static final String NO_HANGUL = "(?s).*[\\uAC00-\\uD7A3].*";
  private static final List<String> IDS = List.of("brush_teeth", "go_,_to");
  private static final String STEP_PROPS = "$.generationConfig.responseSchema.properties.steps.items.properties";

  private MockRestServiceServer server;
  private GeminiTextClient client;

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder().baseUrl("https://gemini.test");
    server = MockRestServiceServer.bindTo(builder).build();
    SystemConfigService systemConfigService = mock(SystemConfigService.class);
    PromptTemplateService promptTemplateService = mock(PromptTemplateService.class);
    when(promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX)).thenReturn("instruction");
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).thenReturn("gemini-flash-latest");
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_THINKING_BUDGET)).thenReturn("UNSET");
    when(systemConfigService.getDouble(ConfigKey.GEMINI_TEXT_TEMPERATURE)).thenReturn(0.0);
    client = new GeminiTextClient(
      builder.build(), new GeminiProperties("key", null, "text-model", "image-model", 1000),
      promptTemplateService, systemConfigService, mock(AiCallLogService.class),
      new PictogramCatalog(IDS, "go_,_to"));
  }

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  private void expectOk() {
    server.expect(method(HttpMethod.POST)).andRespond(withSuccess(OK, MediaType.APPLICATION_JSON));
  }

  @Test
  @DisplayName("ko 일과는 스키마 설명이 지금 한국어 문장 그대로다")
  void ko_schemaUsesCurrentSentences() {
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.generationConfig.responseSchema.properties.title.description")
        .value(ContentLanguageSpec.KO_ROUTINE_TITLE_HINT))
      .andExpect(jsonPath(STEP_PROPS + ".title.description").value(ContentLanguageSpec.KO_STEP_TITLE_HINT))
      .andExpect(jsonPath(STEP_PROPS + ".description.description").value(GeminiRoutineSchemas.STEP_DESCRIPTION_HINT))
      .andExpect(jsonPath(STEP_PROPS + ".pictogramId.description").value(GeminiPictogramPickSpec.PICTOGRAM_ID_DESCRIPTION))
      .andExpect(jsonPath("$.contents[0].parts[0].text", Matchers.containsString("\"nickname\":\"이룸이\"")))
      .andRespond(withSuccess(OK, MediaType.APPLICATION_JSON));

    client.generateRoutineJson("비 오는 날 학교 가기", "하늘이", Set.of(), List.of(), false);

    server.verify();
    assertThat(GeminiRoutineSchemas.STEP_DESCRIPTION_HINT).isEqualTo(ContentLanguageSpec.KO_STEP_DESCRIPTION_HINT);
  }

  @Test
  @DisplayName("es 일과는 스키마 설명이 스페인어를 말하고 요청 본문에 한글이 한 글자도 없다")
  void es_schemaSpeaksSpanish_andBodyHasNoHangul() {
    AiCallContext.setContentLocale(AppLocale.ES);
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.generationConfig.responseSchema.properties.title.description",
        Matchers.containsString("Spanish")))
      .andExpect(jsonPath(STEP_PROPS + ".title.description", Matchers.containsString("Spanish")))
      .andExpect(jsonPath(STEP_PROPS + ".description.description", Matchers.containsString("Spanish")))
      .andExpect(jsonPath(STEP_PROPS + ".pictogramId.description")
        .value(GeminiPictogramPickSpec.PICTOGRAM_ID_DESCRIPTION_GLOBAL))
      .andExpect(content().string(Matchers.not(Matchers.matchesPattern(NO_HANGUL))))
      .andRespond(withSuccess(OK, MediaType.APPLICATION_JSON));

    client.generateRoutineJson("Ir al colegio mañana", null, Set.of(), List.of(), false);

    server.verify();
  }

  @Test
  @DisplayName("es 일과는 실제 이름을 AI 로 보내지 않는다 — 닉네임·글·답변 모두 Elumi 로 바뀐다")
  void es_nicknameNeverLeavesTheServer() {
    AiCallContext.setContentLocale(AppLocale.ES);
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.contents[0].parts[0].text", Matchers.allOf(
        Matchers.containsString("\"nickname\":\"Elumi\""),
        Matchers.containsString("Elumi va al colegio"),
        Matchers.containsString("Elumi lleva el paraguas"),
        Matchers.not(Matchers.containsString("Haneul")))))
      .andRespond(withSuccess(OK, MediaType.APPLICATION_JSON));

    client.generateRoutineJson(
      "Haneul va al colegio", "Haneul", Set.of(), List.of("Haneul lleva el paraguas"), false);

    server.verify();
  }

  @Test
  @DisplayName("ko 픽토그램 고르기는 지금 문장 그대로다")
  void pictogram_ko_unchanged() {
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.systemInstruction.parts[0].text").value(GeminiPictogramPickSpec.PICTOGRAM_PICK_SYSTEM_PROMPT))
      .andExpect(jsonPath("$.generationConfig.responseSchema.properties.pictogramId.description")
        .value(GeminiPictogramPickSpec.PICTOGRAM_ID_DESCRIPTION))
      .andRespond(withSuccess(OK, MediaType.APPLICATION_JSON));

    client.pickPictogramJson("양치해요", "이를 닦아요");

    server.verify();
  }

  @Test
  @DisplayName("es 픽토그램 고르기는 영어 지시로 뜻을 맞춘다 — 입력이 어떤 언어든")
  void pictogram_es_usesLanguageNeutralInstruction() {
    AiCallContext.setContentLocale(AppLocale.ES);
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.systemInstruction.parts[0].text").value(GeminiPictogramPickSpec.PICTOGRAM_PICK_SYSTEM_PROMPT_GLOBAL))
      .andExpect(jsonPath("$.generationConfig.responseSchema.properties.pictogramId.description")
        .value(GeminiPictogramPickSpec.PICTOGRAM_ID_DESCRIPTION_GLOBAL))
      .andExpect(content().string(Matchers.not(Matchers.matchesPattern(NO_HANGUL))))
      .andRespond(withSuccess(OK, MediaType.APPLICATION_JSON));

    client.pickPictogramJson("Lávate los dientes", "Usa el cepillo");

    server.verify();
  }

  @Test
  @DisplayName("OpenAI 클라이언트가 같은 지시를 쓰도록 언어별 값을 한 곳에서 고른다")
  void pictogramHelpersAreShared() {
    assertThat(GeminiPictogramPickSpec.pictogramPickSystemPrompt(AppLocale.KO))
      .isEqualTo(GeminiPictogramPickSpec.PICTOGRAM_PICK_SYSTEM_PROMPT);
    for (AppLocale locale : List.of(AppLocale.EN, AppLocale.JA, AppLocale.ZH, AppLocale.ES)) {
      assertThat(GeminiPictogramPickSpec.pictogramPickSystemPrompt(locale))
        .isEqualTo(GeminiPictogramPickSpec.PICTOGRAM_PICK_SYSTEM_PROMPT_GLOBAL);
    }
    assertThat(GeminiPictogramPickSpec.pictogramPickSchema(AppLocale.KO)).isEqualTo(GeminiPictogramPickSpec.pictogramPickSchema());
    assertThat(GeminiPictogramPickSpec.pictogramPickSchema(AppLocale.JA)).isNotEqualTo(GeminiPictogramPickSpec.pictogramPickSchema());
  }
}
