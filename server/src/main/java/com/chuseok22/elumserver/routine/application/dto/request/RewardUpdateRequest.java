package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "보상(강화물) 수정 요청. 두 값을 모두 비우면 보상을 해제한다")
public record RewardUpdateRequest(

  @Schema(description = "보호자가 정한 보상. null이나 공백이면 보상 없음으로 저장한다", example = "젤리 먹기")
  String rewardText,

  @Schema(description = "보상 프리셋 키(SNACK/VIDEO/PLAY/WALK/CUSTOM). 직접 입력이면 CUSTOM 또는 생략", example = "SNACK")
  String rewardPresetKey
) {

}
