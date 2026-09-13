package com.chuseok22.elumserver.routine.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

/// 보상 설정 화면 상단의 "최근에 정한 보상".
///
/// 온보딩에서 미리 받지 않고 쓰면서 쌓이게 하는 방식이라,
/// 첫 일과에서는 빈 목록이 내려간다. 그때는 화면에서 섹션 자체를 숨긴다.
@Schema(description = "최근에 사용한 보상")
public record RecentRewardResponse(

  @Schema(description = "보상 내용", example = "젤리 먹기")
  String rewardText,

  @Schema(description = "프리셋 키(직접 입력이면 null)", example = "SNACK")
  String rewardPresetKey
) {

}
