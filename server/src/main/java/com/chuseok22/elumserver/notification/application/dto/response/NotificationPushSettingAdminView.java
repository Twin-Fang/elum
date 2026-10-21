package com.chuseok22.elumserver.notification.application.dto.response;

import com.chuseok22.elumserver.notification.core.NotificationType;
import java.util.Map;

/**
 * 관리자 조회용 보호자 푸시 설정: 저장 여부, 전체 스위치, 종류별 스위치
 * 실제 푸시는 전체 && 종류별이 모두 켜져야 나감 (PushDispatcher 와 같은 규칙)
 *
 * @param hasSavedSetting     false 면 저장한 적 없음 (기본값 모두 켜짐)
 * @param isTypeEnabledByType 종류별 스위치 값 (전체 스위치와 무관한 원래 값)
 */
public record NotificationPushSettingAdminView(
  boolean hasSavedSetting,
  boolean isAllEnabled,
  Map<NotificationType, Boolean> isTypeEnabledByType
) {

  public NotificationPushSettingAdminView {
    isTypeEnabledByType = isTypeEnabledByType == null ? Map.of() : Map.copyOf(isTypeEnabledByType);
  }

  /// 이 종류의 푸시가 지금 실제로 나가는지
  public boolean isPushDelivered(NotificationType type) {
    return isAllEnabled && isTypeEnabledByType.getOrDefault(type, true);
  }
}
