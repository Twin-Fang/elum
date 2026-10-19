package com.chuseok22.elumserver.notification.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

/// 검증 어노테이션을 쓰지 않는다. 여섯 값 모두 그대로 저장한다.
@Schema(description = "알림 설정 저장 요청 (푸시 여부만, 알림 목록은 항상 쌓임)")
public record NotificationSettingRequest(
  @Schema(description = "전체 푸시. false 면 종류별 값과 무관하게 푸시 없음")
  boolean allEnabled,
  @Schema(description = "이룸이가 일과를 끝냈을 때")
  boolean routineCompleted,
  @Schema(description = "일과를 이룸이 기기로 보냈을 때")
  boolean routineSent,
  @Schema(description = "함께 돌보는 보호자가 합류했을 때")
  boolean coGuardianJoined,
  @Schema(description = "크레딧이 채워졌을 때")
  boolean creditRefilled,
  @Schema(description = "보낸 의견에 답이 왔을 때")
  boolean feedbackResolved
) {
}
