package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;

class GeminiTextClientTest {

  private final ObjectMapper objectMapper = new ObjectMapper();
  private PromptTemplateService promptTemplateService;
  private GeminiTextClient geminiTextClient;

  // build*UserContent()/questionResponseSchemaFor() 계열 메서드는 HTTP 호출도, DB 조회도
  // 하지 않는 순수 조립 메서드라 promptTemplateService를 실제로 부르지 않는다(fable5
  // 검토에서 지적 — 이전 초안은 여기서 getContent()를 미리 스텁했지만 어떤 테스트도
  // 그 스텁을 실제로 쓰지 않는 죽은 stub이었다). 생성자 의존성 채우기용으로만 목을 만든다.
  @BeforeEach
  void setUp() {
    promptTemplateService = mock(PromptTemplateService.class);
    RestClient restClient = mock(RestClient.class, invocation -> {
      throw new IllegalStateException("이 테스트는 HTTP 호출까지 가면 안 된다 — build*UserContent만 검증한다");
    });
    GeminiProperties geminiProperties = new GeminiProperties("key", null, "text-model", "image-model", 1000);
    geminiTextClient = new GeminiTextClient(restClient, geminiProperties, promptTemplateService);
  }

  @Test
  @DisplayName("buildCreateRoutineUserContent는 <text> 태그 없이 task/routineText/childProfile/additionalAnswers를 담은 JSON을 만든다")
  void buildCreateRoutineUserContent_returnsStructuredJson() throws Exception {
    String json = geminiTextClient.buildCreateRoutineUserContent(
      "비 오는 날 학교 가기", "하늘이", Set.of(SupportGoal.PREPARE_ITEMS), List.of("우산", "물통")
    );

    assertThat(json).doesNotContain("<text>");
    JsonNode node = objectMapper.readTree(json);
    assertThat(node.get("task").asText()).isEqualTo("CREATE_ROUTINE");
    assertThat(node.get("routineText").asText()).isEqualTo("비 오는 날 학교 가기");
    assertThat(node.get("childProfile").get("nickname").asText()).isEqualTo("하늘이");
    assertThat(node.get("childProfile").get("supportGoals").get(0).asText()).isEqualTo("PREPARE_ITEMS");
    assertThat(node.get("additionalAnswers").get(0).asText()).isEqualTo("우산");
    assertThat(node.get("additionalAnswers").get(1).asText()).isEqualTo("물통");
  }

  @Test
  @DisplayName("answers가 null이면 additionalAnswers는 빈 배열로 직렬화된다")
  void buildCreateRoutineUserContent_nullAnswers_serializesEmptyArray() throws Exception {
    String json = geminiTextClient.buildCreateRoutineUserContent(
      "병원 가기", null, Set.of(), null
    );

    JsonNode node = objectMapper.readTree(json);
    assertThat(node.get("additionalAnswers").isArray()).isTrue();
    assertThat(node.get("additionalAnswers")).isEmpty();
  }

  @Test
  @DisplayName("buildQuestionUserContent는 <text> 태그 없이 task/routineText/childProfile을 담는다")
  void buildQuestionUserContent_returnsStructuredJson() throws Exception {
    String json = geminiTextClient.buildQuestionUserContent(
      "내일 비 오는 날 학교 가기", "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW)
    );

    assertThat(json).doesNotContain("<text>");
    JsonNode node = objectMapper.readTree(json);
    assertThat(node.get("task").asText()).isEqualTo("GENERATE_ROUTINE_QUESTIONS");
    assertThat(node.get("routineText").asText()).isEqualTo("내일 비 오는 날 학교 가기");
  }

  @Test
  @DisplayName("questionResponseSchema는 선택된 목표 개수만큼 questions 배열 크기를 강제한다")
  void questionResponseSchema_twoGoals_setsMinMaxItemsToTwo() throws Exception {
    Map<String, Object> schema = geminiTextClient.questionResponseSchemaFor(
      Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW)
    );

    @SuppressWarnings("unchecked")
    Map<String, Object> questionsSchema = (Map<String, Object>)
      ((Map<String, Object>) schema.get("properties")).get("questions");
    assertThat(questionsSchema.get("minItems")).isEqualTo(2);
    assertThat(questionsSchema.get("maxItems")).isEqualTo(2);
  }

  @Test
  @DisplayName("questionResponseSchema는 목표 하나만 선택되면 배열 크기를 1로 강제한다")
  void questionResponseSchema_oneGoal_setsMinMaxItemsToOne() throws Exception {
    Map<String, Object> schema = geminiTextClient.questionResponseSchemaFor(Set.of(SupportGoal.PREPARE_ITEMS));

    @SuppressWarnings("unchecked")
    Map<String, Object> questionsSchema = (Map<String, Object>)
      ((Map<String, Object>) schema.get("properties")).get("questions");
    assertThat(questionsSchema.get("minItems")).isEqualTo(1);
    assertThat(questionsSchema.get("maxItems")).isEqualTo(1);
  }
}
