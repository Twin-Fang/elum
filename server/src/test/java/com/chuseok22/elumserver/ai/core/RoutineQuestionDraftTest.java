package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutineQuestionDraftTest {

  private final ObjectMapper objectMapper = new ObjectMapper();

  @Test
  @DisplayName("supportGoal 필드를 포함한 JSON을 QuestionItem으로 역직렬화한다")
  void deserialize_withSupportGoal_mapsToQuestionItem() throws Exception {
    String json = "{\"questions\":[{\"supportGoal\":\"PREPARE_ITEMS\",\"question\":\"무엇을 챙기나요?\","
      + "\"options\":[{\"emoji\":\"☔\",\"label\":\"우산\"}]}]}";

    RoutineQuestionDraft draft = objectMapper.readValue(json, RoutineQuestionDraft.class);

    assertThat(draft.questions().get(0).supportGoal()).isEqualTo("PREPARE_ITEMS");
    assertThat(draft.questions().get(0).question()).isEqualTo("무엇을 챙기나요?");
  }
}
