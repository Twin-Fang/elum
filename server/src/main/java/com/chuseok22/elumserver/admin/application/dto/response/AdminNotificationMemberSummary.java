package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/**
 * 알림 화면 회원 요약 카드: 표시 이름, 안 읽은 알림 수, 푸시 설정(전체·종류별)
 *
 * @param memberDisplayName 없는 회원(완전 삭제)이면 null
 * @param hasSavedSetting   false 면 저장한 적 없음 (기본값 모두 켜짐)
 * @param typeSwitches      종류 7개 순서대로의 스위치 상태
 */
public record AdminNotificationMemberSummary(
  String memberId,
  String memberDisplayName,
  long unreadCount,
  boolean hasSavedSetting,
  boolean isAllEnabled,
  List<TypeSwitch> typeSwitches
) {

  public AdminNotificationMemberSummary {
    typeSwitches = typeSwitches == null ? List.of() : List.copyOf(typeSwitches);
  }

  /**
   * 종류 하나의 푸시 스위치
   *
   * @param isEnabled   종류별 스위치 값
   * @param isDelivered 전체 스위치까지 따진 실제 발송 여부
   */
  public record TypeSwitch(String typeName, String typeLabel, boolean isEnabled, boolean isDelivered) {

  }

  /// 이 종류(enum 이름)의 푸시가 지금 실제로 나가는지 (모르는 종류는 나간다고 봄)
  public boolean isPushDeliveredFor(String typeName) {
    return typeSwitches.stream()
      .filter(typeSwitch -> typeSwitch.typeName().equals(typeName))
      .findFirst()
      .map(TypeSwitch::isDelivered)
      .orElse(true);
  }

  /// 실제로 푸시가 나가는 종류 수
  public long deliveredTypeCount() {
    return typeSwitches.stream().filter(TypeSwitch::isDelivered).count();
  }
}
