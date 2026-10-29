package com.chuseok22.elumserver.notification.application.dto.response;

import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "알림 설정 응답. 저장된 행이 없으면 모두 true")
public record NotificationSettingResponse(
  @Schema(description = "전체 푸시") boolean allEnabled,
  @Schema(description = "일과 완료") boolean routineCompleted,
  @Schema(description = "일과 보냄") boolean routineSent,
  @Schema(description = "보호자 합류") boolean coGuardianJoined,
  @Schema(description = "크레딧 채움") boolean creditRefilled,
  @Schema(description = "의견 답변") boolean feedbackResolved,
  @Schema(description = "내 이야기 글에 댓글") boolean talkCommented,
  @Schema(description = "내 이야기 글을 가져감") boolean talkImported
) {

  /// 행이 없는 보호자의 기본값: 모두 켜짐
  public static NotificationSettingResponse allEnabledDefault() {
    return new NotificationSettingResponse(true, true, true, true, true, true, true, true);
  }

  public static NotificationSettingResponse from(NotificationSetting setting) {
    return new NotificationSettingResponse(setting.isAllEnabled(), setting.isRoutineCompletedEnabled(),
      setting.isRoutineSentEnabled(), setting.isCoGuardianJoinedEnabled(), setting.isCreditRefilledEnabled(),
      setting.isFeedbackResolvedEnabled(), setting.isTalkCommentedEnabled(), setting.isTalkImportedEnabled());
  }
}
