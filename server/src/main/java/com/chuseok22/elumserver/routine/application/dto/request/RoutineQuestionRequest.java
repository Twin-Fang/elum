package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "AI 추가 질문 생성 요청")
public record RoutineQuestionRequest(

  @Schema(description = "부모가 입력한 자연어 일과 원문", example = "내일 비가 많이 올 예정이야. 아이가 학교에 갈 수 있게 준비해야 해.")
  @NotBlank(message = "rawInputText는 필수입니다.")
  String rawInputText
) {

}
