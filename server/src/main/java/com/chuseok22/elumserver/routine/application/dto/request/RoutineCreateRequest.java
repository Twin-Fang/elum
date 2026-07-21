package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;
import java.util.List;

@Schema(description = "일과 생성 요청")
public record RoutineCreateRequest(

  @Schema(description = "부모가 입력한 자연어 일과 원문", example = "내일 오후 3시에 병원 가기")
  @NotBlank(message = "rawInputText는 필수입니다.")
  String rawInputText,

  @Schema(description = "일과를 수행할 날짜/시각", example = "2026-07-19T15:00:00")
  @NotNull(message = "scheduledAt은 필수입니다.")
  LocalDateTime scheduledAt,

  @Schema(description = "POST /api/routines/questions 질문에 대한 답변(선택지+직접입력 통합). 질문 단계를 거치지 않았으면 생략 가능", example = "[\"우산\", \"우비\", \"여벌 양말\"]")
  List<String> answers
) {

}
