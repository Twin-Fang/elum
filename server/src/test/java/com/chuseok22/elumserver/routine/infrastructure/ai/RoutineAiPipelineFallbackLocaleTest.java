package com.chuseok22.elumserver.routine.infrastructure.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.InputStream;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** AI 가 실패했을 때의 폴백 질문이 요청 언어를 따르고, 헤더가 없으면 이전과 같은 한국어인지 본다. */
@ExtendWith(MockitoExtension.class)
class RoutineAiPipelineFallbackLocaleTest {

  @Mock private TextClientRouter textClientRouter;
  @Mock private ImageClientRouter imageClientRouter;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private FluxImageClient fluxImageClient;
  @Mock private GeminiTextClient geminiTextClient;
  @Mock private TextGenerationClient textGenerationClient;

  private RoutineAiPipeline pipeline;

  @BeforeEach
  void setUp() {
    pipeline = new RoutineAiPipeline(
      textClientRouter, imageClientRouter,
      new CardImageGenerator(imageClientRouter, fluxImageClient, geminiTextClient),
      routineImageStorage, PictogramCatalog.empty());
    lenient().when(textClientRouter.current()).thenReturn(textGenerationClient);
    // AI 가 실패하면 폴백 질문이 나간다
    when(textGenerationClient.generateQuestionJson(any(), any(), any())).thenThrow(new RuntimeException("AI 실패"));
  }

  @AfterEach
  void tearDown() {
    // 다른 테스트로 가짜 문구가 새지 않게 원복한다
    RoutinePhrases.resetStandardForTesting();
  }

  private static Map<String, String> fakeFile(String tag) {
    Map<String, String> map = new HashMap<>();
    map.put("suggestion.01.text", tag + "-text-01");
    for (String goal : List.of("PREPARE_ITEMS", "PREPARE_NEW")) {
      map.put("fallback." + goal + ".question", tag + "-q-" + goal);
      for (int i = 1; i <= 3; i++) {
        map.put("fallback." + goal + ".option." + i + ".emoji", "E" + i);
        map.put("fallback." + goal + ".option." + i + ".label", tag + "-o" + i);
      }
    }
    return map;
  }

  private RoutineAiPipeline.RoutineQuestionResult ask() {
    return pipeline.generateQuestion(
      "하늘이", Set.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW), "내일 비 오는 날");
  }

  @Test
  @DisplayName("헤더 없음(KO): AI 가 실패하면 작업 전과 같은 한국어 질문과 선택지가 나간다")
  void headerless_fallback_isLegacyKorean() throws Exception {
    JsonNode legacy;
    try (InputStream in = getClass().getResourceAsStream("/i18n/golden/routine-phrases-ko.json")) {
      legacy = new ObjectMapper().readTree(in).get("fallback");
    }

    var result = ask();

    assertThat(result.questions()).hasSize(2);
    for (int i = 0; i < 2; i++) {
      String goal = i == 0 ? "PREPARE_ITEMS" : "PREPARE_NEW";
      var item = result.questions().get(i);
      assertThat(item.question()).isEqualTo(legacy.get(goal).get("question").asText());
      assertThat(item.options()).hasSize(legacy.get(goal).get("options").size());
      for (int j = 0; j < item.options().size(); j++) {
        assertThat(item.options().get(j).emoji()).isEqualTo(legacy.get(goal).get("options").get(j).get("emoji").asText());
        assertThat(item.options().get(j).label()).isEqualTo(legacy.get(goal).get("options").get(j).get("label").asText());
      }
    }
  }

  @Test
  @DisplayName("일본어 요청: 폴백 질문은 문구 파일의 대체 순서가 고른 언어다 — 비어 있지 않고 직접 입력이 없다")
  void jaRequest_fallback_followsPhrases() {
    var result = CurrentLocale.callAs(AppLocale.JA, this::ask);

    assertThat(result.questions().get(0).question())
      .isNotBlank()
      .isEqualTo(RoutinePhrases.standard().fallbackQuestion(SupportGoal.PREPARE_ITEMS, AppLocale.JA).question());
    List<RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult> options =
      result.questions().stream().flatMap(q -> q.options().stream()).toList();
    assertThat(options).allSatisfy(option -> assertThat(option.label()).isNotBlank());
  }

  @Test
  @DisplayName("가짜 일본어 문구를 끼우면 일본어 요청의 폴백 질문에 그 문구가 나오고, 헤더 없음은 ko 문구다 (배선 증명)")
  void fakeJaPhrases_reachFallbackQuestion() {
    Map<AppLocale, Map<String, String>> files =
      Map.of(AppLocale.KO, fakeFile("ko"), AppLocale.JA, fakeFile("ja"));
    RoutinePhrases.overrideStandardForTesting(new RoutinePhrases(locale -> files.getOrDefault(locale, Map.of())));

    var ja = CurrentLocale.callAs(AppLocale.JA, this::ask);
    var headerless = ask();

    assertThat(ja.questions()).extracting("question").containsExactly("ja-q-PREPARE_ITEMS", "ja-q-PREPARE_NEW");
    assertThat(ja.questions().get(0).options()).extracting("label").containsExactly("ja-o1", "ja-o2", "ja-o3");
    assertThat(headerless.questions()).extracting("question").containsExactly("ko-q-PREPARE_ITEMS", "ko-q-PREPARE_NEW");
  }
}
