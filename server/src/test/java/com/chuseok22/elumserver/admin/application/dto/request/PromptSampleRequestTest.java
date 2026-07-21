package com.chuseok22.elumserver.admin.application.dto.request;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PromptSampleRequestTest {

  private final ObjectMapper objectMapper = new ObjectMapper();

  @Test
  @DisplayName("previousTitle과 previousSteps를 포함한 JSON을 역직렬화한다")
  void deserialize_withPreviousRoutineFields_populatesFields() throws Exception {
    String json = """
      {
        "content": "시스템 프롬프트",
        "sampleInput": "가방을 챙기는 단계를 추가해줘요",
        "character": null,
        "previousTitle": "학교에 갈 준비를 해요",
        "previousSteps": [
          {"title": "일어나기", "description": "침대에서 일어나요."},
          {"title": "옷 입기", "description": "옷을 입어요."}
        ]
      }
      """;

    PromptSampleRequest request = objectMapper.readValue(json, PromptSampleRequest.class);

    assertThat(request.previousTitle()).isEqualTo("학교에 갈 준비를 해요");
    assertThat(request.previousSteps()).hasSize(2);
    assertThat(request.previousSteps().get(0).title()).isEqualTo("일어나기");
    assertThat(request.previousSteps().get(0).description()).isEqualTo("침대에서 일어나요.");
    assertThat(request.previousSteps().get(1).title()).isEqualTo("옷 입기");
    assertThat(request.previousSteps().get(1).description()).isEqualTo("옷을 입어요.");
  }

  @Test
  @DisplayName("previousTitle과 previousSteps가 없어도(다른 프롬프트 키) 역직렬화가 실패하지 않는다")
  void deserialize_withoutPreviousRoutineFields_defaultsToNull() throws Exception {
    String json = "{\"content\":\"시스템 프롬프트\",\"sampleInput\":\"비 오는 날 학교 가기\",\"character\":null}";

    PromptSampleRequest request = objectMapper.readValue(json, PromptSampleRequest.class);

    assertThat(request.previousTitle()).isNull();
    assertThat(request.previousSteps()).isNull();
  }
}
