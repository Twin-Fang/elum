package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * 새로 그린 그림 후보: 카드 그림은 아직 그대로. 앱이 GET .../image/candidate 로 받아 원래 그림과 나란히 보여 줌
 */
@Schema(description = "고르기 전 새 그림 후보 (카드 그림은 아직 바뀌지 않음)")
public record RoutineStepImageCandidateResponse(

  @Schema(description = "카드 ID")
  String stepId,

  @Schema(description = "새 그림 후보 열쇠. 고를 때(POST .../image/candidate/apply) 그대로 보냄. 이미지 캐시 열쇠로도 씀",
    example = "step-1/ai-0f8fad5b-d9cb-469f-a165-70867728950e.png")
  String candidateImagePath,

  @Schema(description = "AI 그림이 없던 카드에 처음 그린 그림인가 (원래 자리는 픽토그램·기본 카드)", example = "false")
  boolean isFirstPicture
) {

}
