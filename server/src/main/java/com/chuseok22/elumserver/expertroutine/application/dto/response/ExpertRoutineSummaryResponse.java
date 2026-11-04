package com.chuseok22.elumserver.expertroutine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "전문가 일과 목록 1건")
public record ExpertRoutineSummaryResponse(
  @Schema(description = "전문가 일과 id")
  String id,
  @Schema(description = "제목")
  String title,
  @Schema(description = "한 줄 설명. 없으면 null", nullable = true)
  String summary,
  @Schema(description = "분류 (SELF_CARE·DAILY_FLOW·HOUSEHOLD·COMMUNITY·LEARNING·FEELINGS)")
  String category,
  @Schema(description = "카드 글의 언어 코드", example = "ko")
  String language,
  @Schema(description = "카드 수")
  int stepCount,
  @Schema(description = "보상 제안. 없으면 null", nullable = true)
  String rewardText,
  @Schema(description = "첫 카드 픽토그램 id (목록 그림). 없으면 null", nullable = true)
  String coverPictogramId,
  @Schema(description = "첫 카드 예시 이미지 id (목록 그림). 없으면 null", nullable = true)
  String coverExampleImageId
) {

}
