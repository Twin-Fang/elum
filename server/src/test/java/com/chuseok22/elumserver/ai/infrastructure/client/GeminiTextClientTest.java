package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.common.infrastructure.properties.GeminiProperties;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
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
    geminiTextClient = new GeminiTextClient(
      restClient, geminiProperties, promptTemplateService,
      mock(SystemConfigService.class), mock(AiCallLogService.class), PictogramCatalog.empty()
    );
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
    // 실제 이름은 AI 로 나가지 않는다 — 자리표시만 간다 (#374)
    assertThat(node.get("childProfile").get("nickname").asText()).isEqualTo("이룸이");
    assertThat(json).doesNotContain("하늘이");
    assertThat(node.get("childProfile").get("supportGoals").get(0).asText()).isEqualTo("PREPARE_ITEMS");
    assertThat(node.get("additionalAnswers").get(0).asText()).isEqualTo("우산");
    assertThat(node.get("additionalAnswers").get(1).asText()).isEqualTo("물통");
  }

  @Test
  @DisplayName("글 생성 요청에 실제 이름이 없다 — 닉네임은 자리표시, 입력 글·추가 답변 속 이름도 자리표시로 바뀐다 (#374)")
  void buildCreateRoutineUserContent_masksNickname() throws Exception {
    String json = geminiTextClient.buildCreateRoutineUserContent(
      "하늘이가 내일 치과에 가요", "하늘", Set.of(SupportGoal.PREPARE_ITEMS), List.of("하늘이는 칫솔이 필요해요")
    );

    assertThat(json).doesNotContain("하늘");
    JsonNode node = objectMapper.readTree(json);
    assertThat(node.get("childProfile").get("nickname").asText()).isEqualTo("이룸이");
    assertThat(node.get("routineText").asText()).isEqualTo("이룸이가 내일 치과에 가요");
    assertThat(node.get("additionalAnswers").get(0).asText()).isEqualTo("이룸이는 칫솔이 필요해요");
  }

  @Test
  @DisplayName("질문 생성 요청에도 실제 이름이 없다 (#374)")
  void buildQuestionUserContent_masksNickname() throws Exception {
    String json = geminiTextClient.buildQuestionUserContent(
      "하늘이가 내일 치과에 가요", "하늘", Set.of(SupportGoal.PREPARE_ITEMS)
    );

    assertThat(json).doesNotContain("하늘");
    JsonNode node = objectMapper.readTree(json);
    assertThat(node.get("childProfile").get("nickname").asText()).isEqualTo("이룸이");
    assertThat(node.get("routineText").asText()).isEqualTo("이룸이가 내일 치과에 가요");
  }

  @Test
  @DisplayName("이름이 없으면(null·빈 값) nickname 은 null 로 두고 글은 그대로 보낸다 (#374 E1)")
  void buildUserContent_blankNickname_keepsNull() throws Exception {
    JsonNode create = objectMapper.readTree(
      geminiTextClient.buildCreateRoutineUserContent("병원 가기", "  ", Set.of(), List.of()));
    JsonNode question = objectMapper.readTree(
      geminiTextClient.buildQuestionUserContent("병원 가기", null, Set.of()));

    assertThat(create.get("childProfile").get("nickname").isNull()).isTrue();
    assertThat(create.get("routineText").asText()).isEqualTo("병원 가기");
    assertThat(question.get("childProfile").get("nickname").isNull()).isTrue();
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
