package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.MediaType;
import org.springframework.mock.http.client.MockClientHttpRequest;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/**
 * ko 일과의 Gemini 요청 본문 고정: 저장해 둔 본문 <-> 지금 만든 본문 (JSON 트리 비교, 맵 키 순서는 무시)
 */
class GeminiTextClientKoRequestPinTest {

  private static final String OK = "{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"{}\"}]}}]}";
  private static final ObjectMapper MAPPER = new ObjectMapper();

  private MockRestServiceServer server;
  private GeminiTextClient client;
  private final AtomicReference<String> sentBody = new AtomicReference<>();

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder().baseUrl("https://gemini.test");
    server = MockRestServiceServer.bindTo(builder).build();
    SystemConfigService systemConfigService = mock(SystemConfigService.class);
    PromptTemplateService promptTemplateService = mock(PromptTemplateService.class);
    when(promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX)).thenReturn("instruction");
    when(promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX)).thenReturn("question instruction");
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_MODEL)).thenReturn("gemini-flash-latest");
    when(systemConfigService.getString(ConfigKey.GEMINI_TEXT_THINKING_BUDGET)).thenReturn("UNSET");
    when(systemConfigService.getDouble(ConfigKey.GEMINI_TEXT_TEMPERATURE)).thenReturn(0.0);
    client = new GeminiTextClient(
      builder.build(), new GeminiProperties("key", null, "text-model", "image-model", 1000),
      promptTemplateService, systemConfigService, mock(AiCallLogService.class),
      new PictogramCatalog(List.of("brush_teeth", "go_,_to"), "go_,_to"));
    server.expect(request -> sentBody.set(((MockClientHttpRequest) request).getBodyAsString(StandardCharsets.UTF_8)))
      .andRespond(withSuccess(OK, MediaType.APPLICATION_JSON));
  }

  private void assertBodyEquals(String pinnedFileName) throws IOException {
    String pinned = new String(
      new ClassPathResource("ai/request-pin/" + pinnedFileName).getInputStream().readAllBytes(),
      StandardCharsets.UTF_8);
    JsonNode expected = MAPPER.readTree(pinned);
    assertThat(MAPPER.readTree(sentBody.get())).isEqualTo(expected);
  }

  @Test
  @DisplayName("ko 일과 만들기 요청 본문이 저장해 둔 본문과 같다")
  void ko_createBodyPinned() throws IOException {
    client.generateRoutineJson(
      "비 오는 날 학교 가기", "하늘이", Set.of(SupportGoal.PREPARE_ITEMS), List.of("하늘이가 우산을 챙겨요"), true);
    assertBodyEquals("ko-create.json");
  }

  @Test
  @DisplayName("ko 추가 질문 요청 본문이 저장해 둔 본문과 같다")
  void ko_questionBodyPinned() throws IOException {
    client.generateQuestionJson("하늘이", Set.of(SupportGoal.PREPARE_ITEMS), "비 오는 날 학교 가기");
    assertBodyEquals("ko-question.json");
  }

  @Test
  @DisplayName("ko 픽토그램 고르기 요청 본문이 저장해 둔 본문과 같다")
  void ko_pictogramBodyPinned() throws IOException {
    client.pickPictogramJson("양치해요", "이를 닦아요");
    assertBodyEquals("ko-pictogram.json");
  }
}
