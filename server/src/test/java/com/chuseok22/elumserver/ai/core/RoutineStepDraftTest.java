package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RoutineStepDraftTest {

  private final ObjectMapper objectMapper = new ObjectMapper();

  @Test
  @DisplayName("title과 description을 모두 가진 StepDraft로 역직렬화한다")
  void deserialize_withTitleAndDescription_mapsBothFields() throws Exception {
    String json = "{\"title\":\"학교 가기\",\"steps\":[{\"order\":1,\"title\":\"옷을 입어요\","
      + "\"description\":\"학교에 입고 갈 옷을 차례대로 입어요\"}]}";

    RoutineStepDraft draft = objectMapper.readValue(json, RoutineStepDraft.class);

    assertThat(draft.steps().get(0).title()).isEqualTo("옷을 입어요");
    assertThat(draft.steps().get(0).description()).isEqualTo("학교에 입고 갈 옷을 차례대로 입어요");
  }
}
