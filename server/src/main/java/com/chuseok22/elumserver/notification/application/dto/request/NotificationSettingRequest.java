package com.chuseok22.elumserver.notification.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

/// 검증 어노테이션을 쓰지 않는다. 앞 여섯 값은 그대로 저장하고, 이야기 두 값·자동 알림 세 값(#1275)은 null 이면 저장된 값을 그대로 둔다.
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
  boolean feedbackResolved,
  @Schema(description = "내 이야기 글에 댓글이 달렸을 때. 옛 앱은 안 보냄(null = 그대로)")
  Boolean talkCommented,
  @Schema(description = "내 이야기 글을 다른 보호자가 가져갔을 때. 옛 앱은 안 보냄(null = 그대로)")
  Boolean talkImported,
  @Schema(description = "오늘 일과 보내기 알림. 옛 앱은 안 보냄(null = 그대로)")
  Boolean routineNudge,
  @Schema(description = "추천 알림(다시 찾기, 이야기 인기 일과). 옛 앱은 안 보냄(null = 그대로)")
  Boolean suggestion,
  @Schema(description = "요금제 안내 알림(Pro 선물·체험 끝나기 전). 옛 앱은 안 보냄(null = 그대로)")
  Boolean planReminder
) {
}
