package com.chuseok22.elumserver.expertroutine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "전문가 일과 미리 보기: 목록 칸 + 카드 전부")
public record ExpertRoutineDetailResponse(
  @Schema(description = "전문가 일과 id")
  String id,
  @Schema(description = "제목")
  String title,
  @Schema(description = "한 줄 설명. 없으면 null", nullable = true)
  String summary,
  @Schema(description = "분류")
  String category,
  @Schema(description = "카드 글의 언어 코드", example = "ko")
  String language,
  @Schema(description = "보상 제안. 없으면 null", nullable = true)
  String rewardText,
  @Schema(description = "보상 프리셋 키 SNACK·VIDEO·PLAY·WALK. 직접 입력이면 null", nullable = true)
  String rewardPresetKey,
  @Schema(description = "카드 목록 (stepOrder 0부터 순서대로)")
  List<StepResponse> steps
) {

  @Schema(description = "카드 1장")
  public record StepResponse(
    @Schema(description = "순서 (0부터)")
    int stepOrder,
    @Schema(description = "카드 문장")
    String text,
    @Schema(description = "픽토그램 id. 없으면 null", nullable = true)
    String pictogramId,
    @Schema(description = "앱 번들 예시 이미지 id. 없으면 null", nullable = true)
    String exampleImageId
  ) {

  }
}
