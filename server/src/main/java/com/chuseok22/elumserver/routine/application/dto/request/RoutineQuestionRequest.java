package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * AI 추가 질문 생성 요청.
 *
 * <p>일과 생성과 마찬가지로 AI를 부르는 입구다. 제약이 없으면 빈 요청이 그대로
 * Gemini까지 간다 (이슈 #215).
 */
@Schema(description = "AI 추가 질문 생성 요청")
public record RoutineQuestionRequest(

  @Schema(description = "보호자가 입력한 자연어 일과 원문",
    example = "내일 비가 많이 올 예정이야. 이룸이가 학교에 갈 수 있게 준비해야 해.",
    requiredMode = Schema.RequiredMode.REQUIRED)
  @NotBlank(message = "일과 내용을 입력해주세요.")
  @Size(max = 1000, message = "일과 내용은 1000자를 넘을 수 없습니다.")
  String rawInputText
) {

}
