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

  @Test
  @DisplayName("FLUX 용 영어 장면이 오면 받고, 없으면 null 이다 (#373)")
  void deserialize_imagePromptEn() throws Exception {
    String json = "{\"title\":\"t\",\"steps\":[{\"order\":1,\"title\":\"a\",\"description\":\"b\","
      + "\"imagePromptEn\":\"The character puts on a shirt.\"},{\"order\":2,\"title\":\"c\",\"description\":\"d\"}]}";

    RoutineStepDraft draft = objectMapper.readValue(json, RoutineStepDraft.class);

    assertThat(draft.steps().get(0).imagePromptEn()).isEqualTo("The character puts on a shirt.");
    assertThat(draft.steps().get(1).imagePromptEn()).isNull();
  }

  @Test
  @DisplayName("pictogramId 는 선택 필드다 — 있으면 받고, 빠지거나 null 이어도 역직렬화가 실패하지 않는다 (#247)")
  void deserialize_pictogramIdIsOptional() throws Exception {
    String json = "{\"title\":\"t\",\"steps\":["
      + "{\"order\":1,\"title\":\"a\",\"description\":\"b\",\"pictogramId\":\"brush_teeth\"},"
      + "{\"order\":2,\"title\":\"c\",\"description\":\"d\",\"pictogramId\":null},"
      + "{\"order\":3,\"title\":\"e\",\"description\":\"f\"}]}";

    RoutineStepDraft draft = objectMapper.readValue(json, RoutineStepDraft.class);

    assertThat(draft.steps().get(0).pictogramId()).isEqualTo("brush_teeth");
    assertThat(draft.steps().get(1).pictogramId()).isNull();
    assertThat(draft.steps().get(2).pictogramId()).isNull();
  }
}
