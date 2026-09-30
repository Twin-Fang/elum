package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
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
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/**
 * 일과 생성 요청·스키마에 픽토그램이 실리는 모양 (#247). 실제 Gemini 는 부르지 않는다.
 */
class GeminiTextClientPictogramTest {

  private static final List<String> IDS = List.of("brush_teeth", "get_dressed_,_to", "go_,_to");

  private MockRestServiceServer server;
  private AiCallLogService aiCallLogService;
  private GeminiTextClient client;
  private GeminiTextClient clientWithoutCatalog;

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder().baseUrl("https://gemini.test");
    server = MockRestServiceServer.bindTo(builder).build();
    RestClient restClient = builder.build();
    SystemConfigService systemConfigService = mock(SystemConfigService.class);
    aiCallLogService = mock(AiCallLogService.class);
    PromptTemplateService promptTemplateService = mock(PromptTemplateService.class);
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).thenReturn("gemini-flash-latest");
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_THINKING_BUDGET)).thenReturn("UNSET");
    when(systemConfigService.getDouble(ConfigKey.GEMINI_TEXT_TEMPERATURE)).thenReturn(0.0);
    GeminiProperties properties = new GeminiProperties("key", null, "text-model", "image-model", 1000);
    client = new GeminiTextClient(restClient, properties, promptTemplateService, systemConfigService,
      aiCallLogService, new PictogramCatalog(IDS, "go_,_to"));
    clientWithoutCatalog = new GeminiTextClient(restClient, properties, promptTemplateService, systemConfigService,
      aiCallLogService, PictogramCatalog.empty());
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> stepItems(Map<String, Object> schema) {
    Map<String, Object> steps = (Map<String, Object>) ((Map<String, Object>) schema.get("properties")).get("steps");
    return (Map<String, Object>) steps.get("items");
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> pictogramField(Map<String, Object> schema) {
    return (Map<String, Object>) ((Map<String, Object>) stepItems(schema).get("properties")).get("pictogramId");
  }

  @Test
  @DisplayName("카드 스키마의 pictogramId 는 nullable 문자열이고 enum 이 아니며 필수가 아니다 — 지시는 description 에 있다")
  void schema_pictogramIdIsOptionalNullableString() {
    Map<String, Object> field = pictogramField(client.responseSchema(false));

    assertThat(field).isNotNull();
    assertThat(field.get("type")).isEqualTo("string");
    assertThat(field.get("nullable")).isEqualTo(true);
    // 811개 값을 스키마에 enum 으로 넣으면 비대해진다 — 검증은 응답 뒤 서버가 한다.
    assertThat(field).doesNotContainKey("enum");
    assertThat((String) field.get("description"))
      .contains("pictogramCatalog").contains("null").contains("억지로 고르지 마세요");
    // 모델이 빠뜨려도 카드 생성이 실패하지 않게 required 에 넣지 않는다.
    assertThat((List<String>) stepItems(client.responseSchema(false)).get("required")).doesNotContain("pictogramId");
  }

  @Test
  @DisplayName("카탈로그를 못 읽은 서버는 스키마에도 요청에도 싣지 않는다")
  void emptyCatalog_omitsFieldAndRequestCatalog() throws Exception {
    assertThat(pictogramField(clientWithoutCatalog.responseSchema(false))).isNull();

    JsonNode input = new ObjectMapper().readTree(
      clientWithoutCatalog.buildCreateRoutineUserContent("병원 가기", "하늘이", Set.of(), List.of()));
    assertThat(input.has("pictogramCatalog")).isFalse();
  }

  @Test
  @DisplayName("일과 생성 요청 JSON 에 pictogramCatalog(id 문자열 배열)를 싣는다")
  void createUserContent_carriesCatalog() throws Exception {
    JsonNode input = new ObjectMapper().readTree(
      client.buildCreateRoutineUserContent("병원 가기", "하늘이", Set.of(), List.of()));

    assertThat(input.get("pictogramCatalog")).hasSize(3);
    assertThat(input.get("pictogramCatalog").get(1).asText()).isEqualTo("get_dressed_,_to");
  }

  @Test
  @DisplayName("실제 요청 본문에도 스키마의 pictogramId 와 카탈로그가 실린다")
  void createCall_sendsSchemaAndCatalog() {
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.generationConfig.responseSchema.properties.steps.items.properties.pictogramId.nullable")
        .value(true))
      .andExpect(jsonPath("$.contents[0].parts[0].text").value(org.hamcrest.Matchers.containsString("brush_teeth")))
      .andRespond(withSuccess(
        "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"{}\"}]}}]}", MediaType.APPLICATION_JSON));

    client.generateRoutineJson("비 오는 날 학교 가기", null, Set.of(), List.of(), false);

    server.verify();
  }

  @Test
  @DisplayName("카드 추가용 고르기는 제목·설명·카탈로그를 보내고 호출 유형 GEMINI_TEXT_PICTOGRAM 으로 기록한다")
  void pick_sendsCatalogAndLogsOwnType() {
    server.expect(method(HttpMethod.POST))
      .andExpect(jsonPath("$.contents[0].parts[0].text", org.hamcrest.Matchers.containsString("양치해요")))
      .andExpect(jsonPath("$.contents[0].parts[0].text", org.hamcrest.Matchers.containsString("brush_teeth")))
      .andExpect(jsonPath("$.generationConfig.responseSchema.properties.pictogramId.nullable").value(true))
      .andRespond(withSuccess(
        "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"{\\\"pictogramId\\\":\\\"brush_teeth\\\"}\"}]}}]}",
        MediaType.APPLICATION_JSON));

    String json = client.pickPictogramJson("양치해요", "이를 닦아요");

    assertThat(json).contains("brush_teeth");
    verify(aiCallLogService).recordSuccess(
      eq(AiCallType.GEMINI_TEXT_PICTOGRAM), eq("gemini-flash-latest"), anyLong(), any());
  }

  @org.junit.jupiter.api.Test
  @org.junit.jupiter.api.DisplayName("로그에는 811개 카탈로그를 접어 남긴다")
  void foldPictogramCatalog_foldsList() {
    String folded = GeminiTextClient.foldPictogramCatalog(
      "{\"routineText\":\"양치\",\"pictogramCatalog\":[\"a,_to\",\"b\"],\"x\":1}");

    org.assertj.core.api.Assertions.assertThat(folded)
      .contains("\"routineText\":\"양치\"", "\"pictogramCatalog\":\"[생략]\"", "\"x\":1")
      .doesNotContain("a,_to");
    org.assertj.core.api.Assertions.assertThat(GeminiTextClient.foldPictogramCatalog(null)).isNull();
  }
}
